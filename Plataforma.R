dados <- read.table("giro.txt", header = TRUE, sep = "\t", dec = ",", stringsAsFactors = FALSE)

dados$Tempo <- as.numeric(as.character(dados$Tempo))

dados$amplitude <- as.numeric(as.character(dados$amplitude))

plot(dados$Tempo, dados$amplitude, 
     type = "l", 
     col = "purple", 
     xlab = "Tempo", 
     ylab = "Amplitude (N)", 
     main = "Força vs Tempo")

aceleracao <- (dados$amplitude / 70) 

plot(dados$Tempo, aceleracao, 
     type = "l", 
     col = "red",
     xlab = "Tempo", 
     ylab = "Aceleração (m/s²)", 
     main = "Aceleração do Corpo vs Tempo")

velocidade <- numeric(length(aceleracao))


for(i in 3:length(dados$Tempo)) {
  dt <- dados$Tempo[i] - dados$Tempo[i-1]
  velocidade[i] <- velocidade[i-1] + ((aceleracao[i-1] + aceleracao[i]) / 2) * dt
}
plot(dados$Tempo, velocidade, 
     type = "l",
     col = "purple", 
     xlab = "Tempo", 
     ylab = "Velocidade (m/s)", 
     main = "Velocidade vs Tempo")

tv <- 0.6

hmax <- ((tv*tv)*980)/8
hmax