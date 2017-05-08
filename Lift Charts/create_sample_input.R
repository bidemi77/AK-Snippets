library(dplyr)
library(caret)

load("ModelData.Rda")

## Split data out for training/testing using 2015 to predict 2016.

# Predictors for training set
xTrain <- ModelData %>%
  filter(game_year == 2015) %>%
  select(-batter_name, -batter_team, -home_team, 
         -game_date, -homerun, -game_year)

# Predictors for testing set
xTest <- ModelData %>%
  filter(game_year == 2016) %>%
  select(-batter_name, -batter_team, -home_team,
         -game_date, -homerun, -game_year)

# Vector of training outcomes
yTrain <- ModelData %>%
  filter(game_year == 2015) %>%
  select(homerun)
yTrain <- yTrain$homerun

# Vector of testing outcomes
yTest <- ModelData %>%
  filter(game_year == 2016) %>%
  select(homerun)
yTest <- yTest$homerun

# Variables used to look up videos of outcome after the fact
idTest <- ModelData %>%
  filter(game_year == 2016) %>%
  select(batter_name, batter_team, home_team, game_date)

## Preprocessing Categorical Variables

# Separate data to those with factors
xTrainFactor <- select_if(xTrain, is.factor)

# One Hot encode the factor variables 
xTrainOneHot <- data.frame(model.matrix(~.-1, xTrainFactor))

# Find varialbes with near zero variance
nzv <- nearZeroVar(xTrainOneHot, saveMetrics = TRUE) 
nzv$Var <- row.names(nzv)
nzv <- nzv %>%
  filter(nzv == TRUE | zeroVar == TRUE)
nzvVars <- nzv$Var

# Remove variables with near zero variance
xTrainCat <- xTrainOneHot[ , -which(names(xTrainOneHot) %in% nzvVars)]

# Apply the same steps on the test data
xTestFactor <- select_if(xTest, is.factor)
xTestOneHot <- data.frame(model.matrix(~.-1, xTestFactor))
xTestCat <- xTestOneHot[ , -which(names(xTestOneHot) %in% nzvVars)]

# Clean up work space
rm(nzv, xTestFactor, xTestOneHot, xTrainFactor, xTrainOneHot)

## Process numerical variables

# Combine one hot encoded variables and numeric variables
xTrainCombined <- cbind(xTrainCat, select_if(xTrain, is.numeric))

# Calculate correlation 
VarCorrelation <-  cor(xTrainCombined, method = "spearman")

# Find variables with 0.95 or greater correlation 
hcVars <- findCorrelation(VarCorrelation, 
                          cutoff = .95, exact = TRUE, names = TRUE)

# Remove identified highly correlated variables
xTrainProcessed <- xTrainCombined[ , -which(names(xTrainCombined) %in% hcVars)]

# Apply the same steps on the test data
xTestCombined <- cbind(xTestCat, select_if(xTest, is.numeric))
xTestProcessed <- xTestCombined[ , -which(names(xTestCombined) %in% hcVars)]

# Clean up work space
rm(xTestCat, xTrainCat, xTestCombined, xTrainCombined)

## Model fitting

# Baseline model without any tuning
fitControl <- trainControl(method = "none",
                           classProbs = TRUE,
                           summaryFunction = twoClassSummary)

# Benchmark model only uses three variables
xTrainBenchmark <- xTrainProcessed %>%
  select(hit_speed, hit_angle, pullpull)

# Fit benchmark model - logistic
glm1 <- train(xTrainBenchmark, yTrain, 
             method = 'glm',
             family = 'binomial',
             trControl = fitControl, metric = 'ROC')

# Fit Random Forest
rf1 <- train(xTrainProcessed, yTrain, 
             method = 'rf', 
             tuneGrid = data.frame(mtry = 7), 
             trControl = fitControl, metric = 'ROC')

# Print and plot variable importance
rfVarImp <-  varImp(rf1)
plot(rfVarImp)


# Score on the test set
TestScores <- cbind(yTest,
                    predict(rf1, newdata = xTestProcessed, type = 'prob')) %>%
  mutate(HomeRunIndicator = ifelse(yTest == "HomeRun", 1, 0)) %>%
  rename(RF = HomeRun) %>%
  select(HomeRunIndicator, RF)

TestScores <- cbind(TestScores,
                    predict(glm1, newdata = xTestProcessed, type = 'prob')) 

TestScores <- TestScores %>%
  mutate(Benchmark = round(HomeRun, 3)) %>%
  select(HomeRunIndicator, RF, Benchmark)

# Output to CSV
save(TestScores, file = "TestScores.Rda")