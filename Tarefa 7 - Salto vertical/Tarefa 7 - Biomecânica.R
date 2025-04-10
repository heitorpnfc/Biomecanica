# Carregar o pacote necessário
library(plotly)

############################################
## 1) Ler arquivos
############################################
Heitor_SI <- read.table("salto vertical 2024_2/Heitor SI.txt",
                        header = TRUE, sep = "\t", quote = "")
Heitor_CI <- read.table("salto vertical 2024_2/Heitor CI.txt",
                        header = TRUE, sep = "\t", quote = "")
Lucas_SI  <- read.table("salto vertical 2024_2/Lucas SI.txt",
                        header = TRUE, sep = "\t", quote = "")
Lucas_CI  <- read.table("salto vertical 2024_2/Lucas CI.txt",
                        header = TRUE, sep = "\t", quote = "")

# Ajustar nomes das colunas
colnames(Heitor_SI) <- c("Time", "Fz", "COPx", "COPy")
colnames(Heitor_CI) <- c("Time", "Fz", "COPx", "COPy")
colnames(Lucas_SI)  <- c("Time", "Fz", "COPx", "COPy")
colnames(Lucas_CI)  <- c("Time", "Fz", "COPx", "COPy")

# Definição de massa e gravidade
massaHeitor <- 72
massaLucas  <- 88
g <- 9.81

############################################
## 2) Calcular Aceleração e Velocidade
############################################
calculaCinéticas <- function(df, massa) {
  df <- df[order(df$Time), ]
  dt <- diff(df$Time)[1]    # Considera amostragem constante
  Acel <- (df$Fz / massa) - g
  Vel  <- cumsum(Acel) * dt
  df$Accel    <- Acel
  df$Velocity <- Vel
  return(df)
}

Heitor_SI <- calculaCinéticas(Heitor_SI, massaHeitor)
Heitor_CI <- calculaCinéticas(Heitor_CI, massaHeitor)
Lucas_SI  <- calculaCinéticas(Lucas_SI, massaLucas)
Lucas_CI  <- calculaCinéticas(Lucas_CI, massaLucas)

############################################
## 3) Função para gerar gráfico interativo com plotly
############################################
geraPlotly <- function(df, mainTitle) {
  plot_ly(df, x = ~Time) %>%
    add_lines(y = ~Fz, name = "Fz (N)") %>%
    add_lines(y = ~Accel, name = "Acel (m/s²)") %>%
    add_lines(y = ~Velocity, name = "Vel (m/s)") %>%
    layout(title = mainTitle,
           xaxis = list(title = "Time (s)"),
           yaxis = list(title = "Valores"))
}

# Gráficos individuais
p_heitor_SI <- geraPlotly(Heitor_SI, "Heitor SI")
p_heitor_CI <- geraPlotly(Heitor_CI, "Heitor CI")
p_lucas_SI  <- geraPlotly(Lucas_SI,  "Lucas SI")
p_lucas_CI  <- geraPlotly(Lucas_CI,  "Lucas CI")

############################################
## 4) Comparar Fz entre SI e CI (Lucas e Heitor)
############################################

# Para Lucas: comparando Fz em SI e CI
p_lucas_fz <- plot_ly() %>%
  add_lines(data = Lucas_SI, x = ~Time, y = ~Fz, name = "Fz SI", line = list(color = "red")) %>%
  add_lines(data = Lucas_CI, x = ~Time, y = ~Fz, name = "Fz CI", line = list(color = "blue")) %>%
  layout(title = "Lucas Fz: SI vs CI",
         xaxis = list(title = "Time (s)"),
         yaxis = list(title = "Fz (N)"))

# Para Heitor: comparando Fz em SI e CI
p_heitor_fz <- plot_ly() %>%
  add_lines(data = Heitor_SI, x = ~Time, y = ~Fz, name = "Fz SI", line = list(color = "red")) %>%
  add_lines(data = Heitor_CI, x = ~Time, y = ~Fz, name = "Fz CI", line = list(color = "blue")) %>%
  layout(title = "Heitor Fz: SI vs CI",
         xaxis = list(title = "Time (s)"),
         yaxis = list(title = "Fz (N)"))

############################################
## 5) Comparar Fz (SI) entre Lucas e Heitor
############################################
p_si_fz <- plot_ly() %>%
  add_lines(data = Lucas_SI, x = ~Time, y = ~Fz, name = "Lucas SI", line = list(color = "green")) %>%
  add_lines(data = Heitor_SI, x = ~Time, y = ~Fz, name = "Heitor SI", line = list(color = "purple")) %>%
  layout(title = "Fz (SI): Lucas vs Heitor",
         xaxis = list(title = "Time (s)"),
         yaxis = list(title = "Fz (N)"))

############################################
## 6) Comparar Fz (CI) entre Lucas e Heitor
############################################
p_ci_fz <- plot_ly() %>%
  add_lines(data = Lucas_CI, x = ~Time, y = ~Fz, name = "Lucas CI", line = list(color = "green")) %>%
  add_lines(data = Heitor_CI, x = ~Time, y = ~Fz, name = "Heitor CI", line = list(color = "purple")) %>%
  layout(title = "Fz (CI): Lucas vs Heitor",
         xaxis = list(title = "Time (s)"),
         yaxis = list(title = "Fz (N)"))

############################################
## 7) Calcular e plotar pico de força (barplot)
############################################
max_heitor_SI <- max(Heitor_SI$Fz)
max_heitor_CI <- max(Heitor_CI$Fz)
max_lucas_SI  <- max(Lucas_SI$Fz)
max_lucas_CI  <- max(Lucas_CI$Fz)

max_forcas <- data.frame(
  Participante = c("Heitor", "Heitor", "Lucas", "Lucas"),
  Condicao     = c("SI", "CI", "SI", "CI"),
  PicoFz       = c(max_heitor_SI, max_heitor_CI, max_lucas_SI, max_lucas_CI)
)
print(max_forcas)

barplot(height = max_forcas$PicoFz,
        names.arg = paste(max_forcas$Participante, max_forcas$Condicao, sep = "-"),
        col       = c("blue", "blue", "red", "red"),
        xlab      = "Participante-Cond",
        ylab      = "Força Máxima (N)",
        main      = "Comparação do Pico de Força")


p_heitor_SI
p_heitor_CI
p_lucas_SI
p_lucas_CI
p_lucas_fz
p_heitor_fz
p_si_fz
p_ci_fz
