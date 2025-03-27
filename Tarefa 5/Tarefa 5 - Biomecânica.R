library(readxl)
library(signal)
library(ggplot2)
library(dplyr)
library(pracma)
library(zoo)
setwd("E:/GitHub/Biomecanica/Tarefa 5")

dados <- read_excel("CVM1 1.xlsx")
time <- dados$TIME
emg <- dados$EMG

fs <- 1 / mean(diff(time))

calc_rms_movel <- function(sinal, fs, window_length = 0.1, overlap = 0.5) {
  window_samples <- round(window_length * fs)
  overlap_samples <- round(window_samples * overlap)
  
  starts <- seq(1, length(sinal) - window_samples, by = overlap_samples)
  ends <- starts + window_samples - 1
  
  rms_values <- sapply(1:length(starts), function(i) {
    sqrt(mean(sinal[starts[i]:ends[i]]^2))
  })
  
  rms_time <- time[starts + floor(window_samples/2)]
  
  return(data.frame(time = rms_time, rms = rms_values))
}

rms_result <- calc_rms_movel(emg, fs, window_length = 0.1, overlap = 0.5)

analyze_spectrum <- function(sinal, fs) {
  n <- length(sinal)
  
  fft_result <- fft(sinal)
  freq <- (0:(n-1)) * (fs/n)
  half <- floor(n/2)
  
  fft_df <- data.frame(
    frequency = freq[1:half],
    magnitude = Mod(fft_result[1:half]) / n
  )
  fft_df$magnitude[2:half] <- 2 * fft_df$magnitude[2:half]
  
  total_power <- sum(fft_df$magnitude)
  cum_power <- cumsum(fft_df$magnitude)
  
  mean_freq <- sum(fft_df$frequency * fft_df$magnitude) / total_power
  median_freq <- fft_df$frequency[which.min(abs(cum_power - total_power/2))]
  
  segment_length <- min(256, floor(length(sinal)/8))
  psd <- pwelch_manual(sinal, fs, segment_length)
  
  return(list(
    fft = fft_df,
    psd = psd,
    mean_frequency = mean_freq,
    median_frequency = median_freq
  ))
}

pwelch_manual <- function(sinal, fs, segment_length) {
  n_segments <- floor(length(sinal)/segment_length)
  psd <- rep(0, segment_length/2 + 1)
  
  for(i in 1:n_segments) {
    segment <- sinal[((i-1)*segment_length + 1):(i*segment_length)]
    fft_seg <- fft(segment)
    psd <- psd + Mod(fft_seg[1:(segment_length/2 + 1)])^2 / (fs * segment_length)
  }
  
  psd <- psd / n_segments
  freq <- seq(0, fs/2, length.out = segment_length/2 + 1)
  
  return(data.frame(frequency = freq, power = psd))
}

spectral_result <- analyze_spectrum(emg, fs)

calc_envelope <- function(sinal, fs, cutoff = 5) {
  rectified <- abs(sinal)
  
  bf <- butter(4, cutoff/(fs/2), type = "low")
  
  envelope <- filtfilt(bf, rectified)
  
  return(envelope)
}

emg_envelope <- calc_envelope(emg, fs, cutoff = 5)

par(mfrow = c(2, 2))

plot(time, emg, type = "l", col = "gray", 
     main = "Sinal EMG com RMS Móvel (100ms, 50% overlap)",
     xlab = "Tempo (s)", ylab = "Amplitude")
lines(rms_result$time, rms_result$rms, col = "red", lwd = 2)
legend("topright", legend = c("EMG", "RMS Móvel"), col = c("gray", "pink"), lty = 1)

plot(spectral_result$fft$frequency, spectral_result$fft$magnitude, type = "l",
     main = paste("Espectro de Frequência\nMF =", round(spectral_result$mean_frequency, 1),
                  "Hz, MDF =", round(spectral_result$median_frequency, 1), "Hz"),
     xlab = "Frequência (Hz)", ylab = "Magnitude")
abline(v = spectral_result$mean_frequency, col = "blue", lty = 2)
abline(v = spectral_result$median_frequency, col = "green", lty = 2)
legend("topright", legend = c("Espectro", "Média", "Mediana"), 
       col = c("black", "blue", "green"), lty = c(1, 2, 2))

# Alterado para milivolts
plot(spectral_result$psd$frequency, spectral_result$psd$power * 1000, type = "l", 
     main = "Densidade Espectral de Potência (PSD) em mV²/Hz",
     xlab = "Frequência (Hz)", ylab = "Potência (mV²/Hz)")

plot(time, emg, type = "l", col = "gray", 
     main = "Sinal EMG com Envoltório (filtro 5Hz)",
     xlab = "Tempo (s)", ylab = "Amplitude")
lines(time, emg_envelope, col = "red", lwd = 2)
legend("topright", legend = c("EMG", "Envoltório"), col = c("gray", "red"), lty = 1)

resultados <- list(
  time = time,
  emg = emg,
  rms_movel = rms_result,
  spectral_analysis = spectral_result,
  envelope = emg_envelope,
  sampling_rate = fs,
  parameters = list(
    rms_window = "100ms com 50% overlap",
    envelope_cutoff = "5Hz",
    psd_method = "Welch's com segmentos de 256 pontos"
  )
)