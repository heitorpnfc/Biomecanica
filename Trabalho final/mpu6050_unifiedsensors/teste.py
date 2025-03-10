import serial
from vpython import canvas, vector, arrow, box, rate, label
import math
import time

# Configura a porta serial (ajuste conforme necessário)
ser = serial.Serial("COM4", 115200, timeout=1)

# Define os limites do contêiner tridimensional
x_min, x_max = -10, 10
y_min, y_max = 0, 10
z_min, z_max = -10, 10

# Cria a cena VPython
scene = canvas(title="Movimento e Orientação do MPU6050", width=800, height=600)
scene.background = vector(0.2, 0.2, 0.2)

# Cria o contêiner: chão, teto e paredes
floor = box(pos=vector(0, y_min, 0), size=vector(x_max - x_min, 0.2, z_max - z_min),
            color=vector(0.5, 0.5, 0.5), opacity=0.5)
ceiling = box(pos=vector(0, y_max, 0), size=vector(x_max - x_min, 0.2, z_max - z_min),
              color=vector(0.5, 0.5, 0.5), opacity=0.5)
wall_left = box(pos=vector(x_min, (y_max)/2, 0), size=vector(0.2, y_max, z_max - z_min),
                color=vector(0.5, 0.5, 0.5), opacity=0.5)
wall_right = box(pos=vector(x_max, (y_max)/2, 0), size=vector(0.2, y_max, z_max - z_min),
                 color=vector(0.5, 0.5, 0.5), opacity=0.5)
wall_front = box(pos=vector(0, (y_max)/2, z_max), size=vector(x_max - x_min, y_max, 0.2),
                 color=vector(0.5, 0.5, 0.5), opacity=0.5)
wall_back = box(pos=vector(0, (y_max)/2, z_min), size=vector(x_max - x_min, y_max, 0.2),
                color=vector(0.5, 0.5, 0.5), opacity=0.5)

# Cria o objeto que representa o MPU6050 (uma caixa)
device = box(pos=vector(0, (y_min + y_max) / 2, 0),
             length=2, height=0.2, width=1, color=vector(1, 1, 0))

# Cria uma seta para representar a aceleração (para visualização)
accel_arrow = arrow(pos=device.pos, axis=vector(0, 0, 0),
                    color=vector(1, 0, 1), shaftwidth=0.2)

# Cria um label para exibir Yaw, Pitch, Roll e aceleração
info_label = label(pos=vector(0, y_max + 1, 0),
                   text="Yaw: 0.00°, Pitch: 0.00°, Roll: 0.00°\nAccel: 0.00, 0.00, 0.00 m/s²",
                   xoffset=0, yoffset=0, height=16, border=10, box=False, color=vector(1, 1, 1))

def euler_to_rot_matrix(yaw, pitch, roll):
    """
    Converte ângulos de Euler (em radianos) para uma matriz de rotação.
    Composição: R = Rz(yaw) * Ry(pitch) * Rx(roll)
    """
    cy = math.cos(yaw)
    sy = math.sin(yaw)
    cp = math.cos(pitch)
    sp = math.sin(pitch)
    cr = math.cos(roll)
    sr = math.sin(roll)
    
    # Retorna uma matriz 3x3 (lista de listas)
    return [[cy * cp,            cy * sp * sr - sy * cr,   cy * sp * cr + sy * sr],
            [sy * cp,            sy * sp * sr + cy * cr,   sy * sp * cr - cy * sr],
            [-sp,                cp * sr,                  cp * cr]]

# Variáveis para integração (posição e velocidade)
velocity = vector(0, 0, 0)
prev_time = time.time()

# Parâmetros para filtro simples contra ruído
accel_threshold = 0.05  # m/s²: valores abaixo serão tratados como zero
velocity_damping = 0.95  # amortecimento para evitar drift excessivo

while True:
    rate(100)  # Limita a 100 iterações por segundo
    current_time = time.time()
    dt = current_time - prev_time
    prev_time = current_time
    # Limita dt para evitar saltos em caso de travamento momentâneo
    if dt > 0.05:
        dt = 0.05

    if ser.in_waiting:
        try:
            # Lê uma linha da serial e converte
            line = ser.readline().decode('utf-8').strip()
            if not line:
                continue

            # Espera o formato: "yaw,pitch,roll,ax_lin,ay_lin,az_lin"
            parts = line.split(',')
            if len(parts) != 6:
                continue

            yaw_deg, pitch_deg, roll_deg, ax_lin, ay_lin, az_lin = map(float, parts)

            # Atualiza a orientação do dispositivo para exibição
            yaw   = math.radians(yaw_deg)
            pitch = math.radians(pitch_deg)
            roll  = math.radians(roll_deg)
            R = euler_to_rot_matrix(yaw, pitch, roll)
            # Para exibir a orientação, aplicamos R à direção padrão
            new_axis = vector(R[0][0], R[1][0], R[2][0])
            new_up   = vector(R[0][1], R[1][1], R[2][1])
            device.axis = new_axis
            device.up = new_up

            # A aceleração linear já vem do Arduino com a gravidade removida
            # Use-a diretamente (não aplicamos rotação, de forma que não dependa do YPR)
            accel_vec = vector(ax_lin, ay_lin, az_lin)

            # Aplica um "deadzone" para eliminar ruído de baixa magnitude
            if abs(accel_vec.x) < accel_threshold:
                accel_vec.x = 0
            if abs(accel_vec.y) < accel_threshold:
                accel_vec.y = 0
            if abs(accel_vec.z) < accel_threshold:
                accel_vec.z = 0

            # Amortece a velocidade (para reduzir drift quando o sensor está parado)
            velocity = velocity * velocity_damping

            # Integra aceleração para atualizar a velocidade e posição
            velocity = velocity + accel_vec * dt
            device.pos = device.pos + velocity * dt

            # Verifica colisão com as paredes do contêiner e corrige a posição
            half_length = device.length / 2
            half_height = device.height / 2
            half_width  = device.width / 2

            if device.pos.x < x_min + half_length:
                device.pos.x = x_min + half_length
                velocity.x = 0
            if device.pos.x > x_max - half_length:
                device.pos.x = x_max - half_length
                velocity.x = 0
            if device.pos.y < y_min + half_height:
                device.pos.y = y_min + half_height
                velocity.y = 0
            if device.pos.y > y_max - half_height:
                device.pos.y = y_max - half_height
                velocity.y = 0
            if device.pos.z < z_min + half_width:
                device.pos.z = z_min + half_width
                velocity.z = 0
            if device.pos.z > z_max - half_width:
                device.pos.z = z_max - half_width
                velocity.z = 0

            # Atualiza a seta de aceleração (com fator de escala para visualização)
            scale_factor = 0.2
            accel_arrow.pos = device.pos
            accel_arrow.axis = accel_vec * scale_factor

            # Atualiza o label de informações
            info_label.text = (f"Yaw: {yaw_deg:.2f}°, Pitch: {pitch_deg:.2f}°, Roll: {roll_deg:.2f}°\n"
                               f"Accel: {ax_lin:.2f}, {ay_lin:.2f}, {az_lin:.2f} m/s²")
        except Exception as e:
            print("Erro ao ler/processar dados:", e)
