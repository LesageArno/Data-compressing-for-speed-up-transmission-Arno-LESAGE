library(dplyr)
library(ggplot2)


#### Import data ####
classifierList <- list()
classifierList[["NoSplit"]] <- read.csv("OUT\\nosplitBenchmark.out", stringsAsFactors = TRUE, strip.white = TRUE) %>% select(-benchID) %>% mutate(source = as.factor("NoSplit"))
classifierList[["Split"]] <- read.csv("OUT\\splitBenchmark.out", stringsAsFactors = TRUE, strip.white = TRUE) %>% select(-benchID) %>% mutate(source = as.factor("Split"))
classifierList[["O1"]] <- read.csv("OUT\\overflow1Benchmark.out", stringsAsFactors = TRUE, strip.white = TRUE) %>% select(-benchID) %>% mutate(source = as.factor("Overflow1"))
classifierList[["O2"]] <- read.csv("OUT\\overflow2Benchmark.out", stringsAsFactors = TRUE, strip.white = TRUE) %>% select(-benchID) %>% mutate(source = as.factor("Overflow2"))
classifierList[["O4"]] <- read.csv("OUT\\overflow4Benchmark.out", stringsAsFactors = TRUE, strip.white = TRUE) %>% select(-benchID) %>% mutate(source = as.factor("Overflow4"))
classifierList[["O8"]] <- read.csv("OUT\\overflow8Benchmark.out", stringsAsFactors = TRUE, strip.white = TRUE) %>% select(-benchID) %>% mutate(source = as.factor("Overflow8"))
classifierList[["O12"]] <- read.csv("OUT\\overflow12Benchmark.out", stringsAsFactors = TRUE, strip.white = TRUE) %>% select(-benchID) %>% mutate(source = as.factor("Overflow12"))

for (classifier in names(classifierList)) {
    classifierList[[classifier]] <- classifierList[[classifier]] %>% 
        mutate(inFile = factor(inFile, 
                               levels = c(
                                   "smallInt_small", "smallInt_medium", "smallInt_large", "smallInt_superLarge",
                                   "largeInt_small", "largeInt_medium", "largeInt_large", "largeInt_superLarge",
                                   "boltzmann_small", "boltzmann_medium", "boltzmann_large", "boltzmann_superLarge",
                                   "superLargeInt_small", "superLargeInt_medium", "superLargeInt_large"
                               ),
                               ordered = TRUE
                        )
        
        )
}

allClassifier <- classifierList$NoSplit
for (classifier in names(classifierList)) {
    if (classifier != "NoSplit") {
        allClassifier <- bind_rows(allClassifier,classifierList[[classifier]])
    }
}

#### Functions ####
getErrorMargin <- function(classifier) {
    return(
        classifier %>% 
            group_by(inFile, source, func) %>% 
            summarise(
                mu = mean(time),
                std = sd(time),
                n = n(),
                EM95_low = max(0,mu - 1.96 * std/sqrt(n)),
                EM95_high = mu + 1.96 * std/sqrt(n),
                .groups = "drop"
            ) %>%
            filter(func %in% c("transmit", "transmitRaw")) %>%
            droplevels()
    )
}

getTimeDecomp <- function(classifier) {
    return(
        classifier %>%
            filter(func!="transmitRaw") %>%
            group_by(inFile, source, func) %>%
            summarise(
                mu = mean(time),
                .groups = "drop"
            )
    )
}

#### Plots ####
##### Average transmission time with respect to compressor and Benchmark output #####
allClassifierEM <- getErrorMargin(allClassifier)
ggplot(allClassifierEM, aes(x = inFile, y = mu, color = func, group = func)) +
    geom_point(position = position_dodge(width = 0.3), size = 3) +
    geom_errorbar(
        aes(ymin = EM95_low, ymax = EM95_high),
        width = 0.2,
        position = position_dodge(width = 0.3)
    ) +
    geom_line(position = position_dodge(width = 0.3)) +
    facet_wrap(~source) +
    labs(
        x = "Benchmark files",
        y = "Average transmission time (in seconds)",
        color = "Transmission type"
    ) +
    theme(axis.text.x = element_text(angle = 90, hjust = 1)) +
    ggtitle("Average transmission time with respect to the compressor and benchmark output")

##### Average transmission time differenec with respect to compressor and Benchmark output #####
allClassifierEM <- getErrorMargin(allClassifier)
allClassifierDiff <- allClassifierEM %>%
    select(inFile, source, func, mu, EM95_low, EM95_high) %>%
    tidyr::pivot_wider(
        names_from = func,
        values_from = c(mu, EM95_low, EM95_high)
    ) %>%
    mutate(
        diff_mu = mu_transmitRaw - mu_transmit,
        diff_low = EM95_low_transmitRaw - EM95_low_transmit,
        diff_high = EM95_high_transmitRaw - EM95_high_transmit
    )

##### Average difference in transmission time between transmitRaw and transmit ####
ggplot(allClassifierDiff, aes(x = inFile, y = diff_mu)) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
    geom_point(size = 3, color = "steelblue") +
    geom_errorbar(aes(ymin = diff_low, ymax = diff_high), width = 0.2, color = "steelblue") +
    facet_wrap(~source) +
    labs(
        x = "Benchmark files",
        y = "Difference in average transmission time (transmitRaw - transmit)",
        title = "Average difference in transmission time between transmitRaw and transmit",
        subtitle = "Negative values → transmit slower"
    ) +
    theme(
        axis.text.x = element_text(angle = 90, hjust = 1),
        panel.grid.minor = element_blank()
    )
##### Total average process time with respect to compressor and benchmark output ####
allClassifierTimeDecomp <- getTimeDecomp(allClassifier)
ggplot(allClassifierTimeDecomp, aes(x = inFile, y = mu, fill = func)) +
    geom_bar(stat = "identity") +
    facet_wrap(~source) +
    scale_fill_manual(values = c(
        "compress" = "#1f77b4",
        "decompress" = "#2ca02c",
        "transmit" = "#ff7f0e"
    )) +
    labs(
        x = "Benchmark files",
        y = "Total average process time (in seconds)",
        fill = "Operation"
    ) +
    theme(axis.text.x = element_text(angle = 90, hjust = 1)) +
    ggtitle("Total average process time with respect to compressor and benchmark output")





#### Hypothesis testing (Fisher-Pitman) ####
##### Is transmit time generally smaller than transmit raw time among all classifiers ####
transmitTime <- c(
    as.vector(allClassifier %>% filter(func=="transmit") %>% select(time))$time,
    as.vector(allClassifier %>% filter(func=="transmitRaw") %>% select(time))$time
)
group <- as.factor(c(rep("transmit", length(transmitTime)%/%2), rep("transmitRaw", length(transmitTime)%/%2)))
coin::oneway_test(transmitTime~group, alternative="less")
#'	    Asymptotic Two-Sample Fisher-Pitman Permutation Test
#'
#'  data:  transmitTime by group (transmit, transmitRaw)
#'  Z = -4.6919, p-value = 1.353e-06
#'  alternative hypothesis: true mu is less than 0




##### Is transmit time generally smaller than transmit raw time among all classifiers and larger files ####
transmitTime <- c(
    as.vector(allClassifier %>% filter(func=="transmit", inFile %in% c("smallInt_superLarge", "largeInt_superLarge", "bolzmann_superLarge")) %>% select(time))$time,
    as.vector(allClassifier %>% filter(func=="transmitRaw", inFile %in% c("smallInt_superLarge", "largeInt_superLarge", "bolzmann_superLarge")) %>% select(time))$time
)
group <- as.factor(c(rep("transmit", length(transmitTime)%/%2), rep("transmitRaw", length(transmitTime)%/%2)))

coin::oneway_test(transmitTime~group, alternative="less")
#'	    Asymptotic Two-Sample Fisher-Pitman Permutation Test
#'	    
#'	data:  transmitTime by group (transmit, transmitRaw)
#'	Z = -4.9154, p-value = 4.43e-07
#'	alternative hypothesis: true mu is less than 0






##### Is transmit time generally smaller than transmit raw time among all classifiers and large files ####
transmitTime <- c(
    as.vector(allClassifier %>% filter(func=="transmit", inFile %in% c("smallInt_large", "largeInt_large", "bolzmann_large")) %>% select(time))$time,
    as.vector(allClassifier %>% filter(func=="transmitRaw", inFile %in% c("smallInt_large", "largeInt_large", "bolzmann_large")) %>% select(time))$time
)
group <- as.factor(c(rep("transmit", length(transmitTime)%/%2), rep("transmitRaw", length(transmitTime)%/%2)))

coin::oneway_test(transmitTime~group, alternative="less")
#'	    Asymptotic Two-Sample Fisher-Pitman Permutation Test
#'	    
#'  data:  transmitTime by group (transmit, transmitRaw)
#'	Z = -2.6786, p-value = 0.003697
#'  alternative hypothesis: true mu is less than 0






##### Is transmit time generally smaller than transmit raw time among all classifiers and medium-sized files ####
transmitTime <- c(
    as.vector(allClassifier %>% filter(func=="transmit", inFile %in% c("smallInt_medium", "largeInt_medium", "bolzmann_medium")) %>% select(time))$time,
    as.vector(allClassifier %>% filter(func=="transmitRaw", inFile %in% c("smallInt_medium", "largeInt_medium", "bolzmann_medium")) %>% select(time))$time
)
group <- as.factor(c(rep("transmit", length(transmitTime)%/%2), rep("transmitRaw", length(transmitTime)%/%2)))
coin::oneway_test(transmitTime~group, alternative="less")
#'  	Asymptotic Two-Sample Fisher-Pitman Permutation Test
#' 
#'  data:  transmitTime by group (transmit, transmitRaw)
#'  Z = -0.12648, p-value = 0.4497
#'  alternative hypothesis: true mu is less than 0






##### Is transmit time generally smaller than transmit raw time among all classifiers and small files ####
transmitTime <- c(
    as.vector(allClassifier %>% filter(func=="transmit", inFile %in% c("smallInt_small", "largeInt_small", "bolzmann_small")) %>% select(time))$time,
    as.vector(allClassifier %>% filter(func=="transmitRaw", inFile %in% c("smallInt_small", "largeInt_small", "bolzmann_small")) %>% select(time))$time
)
group <- as.factor(c(rep("transmit", length(transmitTime)%/%2), rep("transmitRaw", length(transmitTime)%/%2)))
coin::oneway_test(transmitTime~group, alternative="less")
#'	    Asymptotic Two-Sample Fisher-Pitman Permutation Test
#'	    
#'  data:  transmitTime by group (transmit, transmitRaw)
#'  Z = -0.60948, p-value = 0.2711
#'  alternative hypothesis: true mu is less than 0





#### Compute Ideal delay ####
allClassifierFile <- allClassifier    
allClassifierFile$inFile <-  case_match(
    allClassifier$inFile,
    c("smallInt_small", "largeInt_small", "superLargeInt_small", "boltzmann_small") ~ 10^3,
    c("smallInt_medium", "largeInt_medium", "superLargeInt_medium", "boltzmann_medium") ~ 10^5,
    c("smallInt_large", "largeInt_large", "superLargeInt_large", "boltzmann_large") ~ 10^6,
    c("smallInt_superLarge", "largeInt_superLarge", "boltzmann_superLarge") ~ 4*10^6,
)
lmTransmitRaw <- lm(time~inFile, data = allClassifierFile %>% filter(func=="transmitRaw"))
tr_coeff <- lmTransmitRaw$coefficients
lmTransmit <- lm(time~inFile, data = allClassifierFile %>% filter(func=="transmit"))
t_coeff <- lmTransmit$coefficients

t <- ceiling((tr_coeff[1]-t_coeff[1])/(t_coeff[2]-tr_coeff[2]))
t
