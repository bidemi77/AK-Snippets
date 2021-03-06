Meaningful Model Comparison
===========================

#### Alan Kessler

Jeremy Achin from DataRobot presented to a group of actuaries on gradient boosting machines. In part of the presentation, he talked about how comparing models is more than comparing fit statistics. To prove his point he showed a chart that binned the differences in model predictions and compared the results to the holdout observations.

I could not find the code to generate this kind of plot, so I used data from my [Home Run](https://github.com/alanrkessler/homerun) project to recreate it. I did not have a benchmark for that work so I created one that uses the three most important variables (hit speed, hit angle, and pull indicator) in a [logistic regression](create_sample_input.R).

Load Data
---------

``` r
library(pROC)
library(reshape2)
library(dplyr)
library(ggplot2)

load("TestScores.Rda")
```

Calculate AUC
-------------

Both models do a good job of predicting with the random forest performing best. The goal of the plot is to look into the differences between the models more closely.

``` r
# Random Forest
auc(TestScores$HomeRunIndicator, TestScores$RF)
```

    ## Area under the curve: 0.9773

``` r
# Benchmark
auc(TestScores$HomeRunIndicator, TestScores$Benchmark)
```

    ## Area under the curve: 0.9243

Prep Data for Plotting
----------------------

``` r
# Number of buckets
nbins <- 10

# Group into bins and calculate the difference
ScoreCompare <- TestScores %>%
  mutate(Difference = RF - Benchmark) %>%
  mutate(Bin = ntile(Difference, nbins)) %>%
  group_by(Bin) %>%
  summarise(Actual = mean(HomeRunIndicator),
            RF = mean(RF),
            Benchmark = mean(Benchmark))

# Reshape data
SCLong <- melt(ScoreCompare, id.vars = 1)
```

Plot
----

``` r
ggplot(SCLong, aes(Bin, value, group=variable)) +
  geom_point(aes(shape=variable, color=variable, size=variable)) +
  scale_shape_manual(values=c(95, 19, 1)) +
  scale_size_manual(values=c(10,2,2)) +
  scale_color_manual(values=c('black','green3', 'red')) + 
  scale_x_continuous(breaks=1:nbins) +
  ylab("Home Run Probability") +
  xlab("Prediction Difference Bucket") +
  ggtitle("Dual Lift Model Comparison") +
  theme(legend.title = element_blank())
```

![](README_files/figure-markdown_github/unnamed-chunk-4-1.png)
