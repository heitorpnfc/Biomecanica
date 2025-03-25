# Heitor Pereira Nunes F. Cunha 12111EBI027

library(readxl)
library(ggplot2)

# Plotagem do arquivo

# Carregar o arquivo Excel
file_path <- "C:/Users/heito/Downloads/CVM1 1.xlsx" 
df <- read_excel(file_path, sheet = "CVM1")

# Renomear colunas removendo espaços
names(df) <- trimws(names(df))

# Criar o gráfico
ggplot(df, aes(x = TIME, y = EMG)) +
  geom_line(color = "blue") +
  labs(title = "Sinal Original", x = "Tempo (s)", y = "Amplitude") +
  theme_minimal()

#--------------------------------
# Plotagem Meia onda

# Carregar pacotes
library(readxl)
library(ggplot2)

# Carregar o arquivo Excel
file_path <- "C:/Users/heito/Downloads/sinalEMG 1.xlsx"
df <- read_excel(file_path, sheet = "sinalEMG")

# Renomear colunas removendo espaços
names(df) <- trimws(names(df))

# Aplicar retificação de meia onda
df$EMG_retificado <- pmax(df$EMG2, 0)

# Criar a plotagem do sinal retificado
ggplot(df, aes(x = TIME, y = EMG_retificado)) +
  geom_line(color = "red") +
  labs(title = "Sinal EMG - Retificação de Meia Onda", x = "Tempo (s)", y = "Amplitude") +
  theme_minimal()

#--------------------------------
# Plotagem onda completa

# Carregar pacotes
library(readxl)
library(ggplot2)

# Carregar o arquivo Excel
file_path <- "C:/Users/heito/Downloads/sinalEMG 1.xlsx"
df <- read_excel(file_path, sheet = "sinalEMG")

# Renomear colunas removendo espaços
names(df) <- trimws(names(df))

# Aplicar retificação de onda completa
df$EMG_retificado <- abs(df$EMG2)

# Criar a plotagem do sinal retificado
ggplot(df, aes(x = TIME, y = EMG_retificado)) +
  geom_line(color = "orange") +
  labs(title = "Sinal EMG - Retificação de Onda Completa", x = "Tempo (s)", y = "Amplitude") +
  theme_minimal()






