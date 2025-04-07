# Carregar os pacotes necessários
library(ggplot2)
library(reshape2)

# Função para calcular o impulso usando a regra do trapézio
calc_impulse <- function(time, force) {
  impulse <- sum(diff(time) * (head(force, -1) + tail(force, -1)) / 2)
  return(impulse)
}

# Vetores com os nomes dos arquivos (assumindo que os arquivos estão no diretório de trabalho)
ci_files <- c("Luiza CI.txt", "Anna CI.txt", "Heitor CI.txt", "João CI.txt", 
              "Marcos CI.txt", "Eduardo CI.txt", "Ivan CI.txt", "Lucas CI.txt", 
              "Nivea CI.txt", "Heloisa CI.txt")

si_files <- c("Luiza CI.txt", "Anna CI.txt", "Heitor CI.txt", "João CI.txt", 
              "Marcos CI.txt", "Eduardo CI.txt", "Ivan CI.txt", "Lucas CI.txt", 
              "Nivea CI.txt", "Heloisa CI.txt")

# Função para extrair o nome do participante a partir do nome do arquivo
extract_name <- function(filename, condition) {
  # Remove o sufixo " CI.txt" ou " SI.txt"
  name <- sub(paste0(" ", condition, "\\.txt$"), "", filename)
  return(name)
}

setwd("C:/Users/heito/Documents/GitHub/Biomecanica/Atividade salto vertical/salto vertical 2024_2/CI")

# Calcular o impulso para cada arquivo da condição CI
impulse_CI <- sapply(ci_files, function(file) {
  data <- read.delim(file, header = TRUE, sep = "\t")
  calc_impulse(data$Time, data$Fz)
})

setwd("C:/Users/heito/Documents/GitHub/Biomecanica/Atividade salto vertical/salto vertical 2024_2/SI")

# Calcular o impulso para cada arquivo da condição SI
impulse_SI <- sapply(si_files, function(file) {
  data <- read.delim(file, header = TRUE, sep = "\t")
  calc_impulse(data$Time, data$Fz)
})

# Extrair os nomes dos participantes
names_CI <- sapply(ci_files, extract_name, condition = "CI")
names_SI <- sapply(si_files, extract_name, condition = "SI")

# Criar um data frame com os resultados (assumindo que os nomes em CI e SI correspondem)
impulse_df <- data.frame(
  Participant = names_CI,
  Impulse_CI = impulse_CI,
  Impulse_SI = impulse_SI
)

print(impulse_df)

# Preparar os dados para plotagem (melt para formato longo)
impulse_melt <- melt(impulse_df, id.vars = "Participant", 
                     variable.name = "Condition", value.name = "Impulse")

# Plotar a comparação de impulso entre as condições para cada participante
ggplot(impulse_melt, aes(x = Participant, y = Impulse, fill = Condition)) +
  geom_bar(stat = "identity", position = position_dodge()) +
  labs(title = "Comparação do Impulso Gerado por Participante",
       x = "Participante",
       y = "Impulso (N.s)",
       fill = "Condição") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
