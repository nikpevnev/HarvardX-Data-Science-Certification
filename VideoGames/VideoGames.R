##########################################################
# Video Games Sales Project -ML
# Nik Pevnev
# 3/24/2025
##########################################################

# -----
# Intro
# -----

# Video Games Sales with Ratings project is based on creating a predictive 
# machine learning algorithm trained on provided video games sales data and 
# RMSE tested with train set to predict game's global sales.
# Final deliverables of the project will be: .Rmd file, .DF document,
# and an R script.
# Data is based on ML friendly Kaggle data source: 
# https://www.kaggle.com/datasets/rush4ratio/video-game-sales-with-ratings

# --------
# Packages
# --------

# Install necessary packages
if(!require(tidyverse)) 
  install.packages("tidyverse", repos = "http://cran.us.r-project.org")
if(!require(caret)) 
  install.packages("caret", repos = "http://cran.us.r-project.org")
if(!require(dplyr)) 
  install.packages("dplyr", repos = "http://cran.us.r-project.org")
if(!require(h2o)) 
  install.packages("h2o", repos = "http://cran.us.r-project.org")

# Import libraries
library(tidyverse)
library(caret)  
library(dplyr)
library(h2o)

# ------------------------------------------------------------------------
# Download Kaggle data source from GDrive automatically
# https://www.kaggle.com/datasets/rush4ratio/video-game-sales-with-ratings
# ------------------------------------------------------------------------

# (1) Define variable file names
zipFile <- "archive.zip"
filePathName <- "Video_Games_Sales_as_at_22_Dec_2016.csv"    

# (2) Download file from Google Drive (publicly shared)
if(!file.exists(zipFile))
  download.file("https://drive.google.com/uc?authuser=0&id=1l6Nl7CXEpoB7lNCKAohln9KtcMoWqPmW&export=download", zipFile)

# (3) Extract .csv file from .zip
gameSalesFile <- filePathName
if(!file.exists(gameSalesFile))
  unzip(zipFile, filePathName)
games <- read.csv(gameSalesFile)

# -------
# Dataset
# -------

# (1) Check raw data from Kaggle
glimpse(games) 
# We have 16,719 rows and 16 columns across dataset as noted in glimpse(games)

# (2) Review stats for each field
summary(games)
# Summary of raw dataset reveals a big number of NAs in Critic_Score, 
# Critic_Count, and User_Count columns that need to pre-processed 
# for successful ML run

# (3) We also want to research :character fields, in particular Platforms 
# on which games are built.
games %>%
  group_by(Name, Publisher, Platform) %>%
  count(sort = TRUE)
# We see that GG and PCFX are only counted once, meaning training data set might 
# not have all of the feature values, hence we can remove these 2 rows
# This is to avoid issues with train / test data separation

# (4) Check User_Score field values to see what distinct values it has
games %>%
  distinct(User_Score) %>%
  filter(!grepl("^\\d*\\.?\\d+$", as.character(User_Score))) %>%
  arrange(User_Score)
# We need to be careful with "" and "tbd" values in the dataset

# -------------
# Data Cleaning
# -------------

# (1) Data cleaning and preparation where character fields are transformed into 
# a factor and numeric values are continuous
games_clean <- games %>%
  mutate(
    Year_of_Release = as.numeric(ifelse(grepl("^[0-9]+$"
                                        , Year_of_Release)
                                        , Year_of_Release, NA)),  
    User_Score = 
        as.numeric(ifelse(User_Score 
        %in% c("", "NA", "tbd")
        , NA, User_Score)), # Handle other non-numeric values
    Rating = factor(Rating),
    Genre = factor(Genre),
    Platform = factor(Platform)
  ) %>%
  filter(!is.na(Global_Sales)) %>%  # Remove rows with missing target variable
  filter(!Platform %in% c("GG", "PCFX")) %>% # Remove unwanted platforms
  filter(!Rating %in% c("AO", "RP", "K-A")) # Remove unwanted rating

# (2) Remove rows with NA in clean data set
games_clean <- na.omit(games_clean)

# (3) Update rare publishers to "Other" if they have <= 25 games
publisher_count <- table(games_clean$Publisher)
rare_publishers <- names(publisher_count[publisher_count <= 25])
games_clean <- games_clean %>%
  mutate(Publisher = ifelse(Publisher %in% rare_publishers, "Other", Publisher))
games_clean$Publisher <- as.factor(games_clean$Publisher) # Convert to factor 

# (4) Check Rating field values to see what distinct values it has
games_clean %>%
  group_by(Rating) %>%
  count(sort = TRUE)
# =============== CLEAN DATA =============== 
games_clean <- games_clean %>%
  filter(!Rating %in% c("AO", "RP", "K-A")) # Remove unwanted rating
# We see that AO, K-A, RP are only counted once, meaning training data set might 
# not have all of the feature values, hence we can remove these ratings
# This is to avoid issues with train / test data separation

# (5) Check the new data structure of the cleaned data
glimpse(games_clean)
summary(games_clean)
# Now data looks better for ML processing :)

# ----------------
# Data Preparation
# ----------------

# (1) Split while maintaining both distributions for Global Sales
set.seed(123)
trainIndex <- createDataPartition(games_clean$Global_Sales, p = 0.8
                                  , list = FALSE)
train_data <- games_clean[trainIndex, ]
test_data <- games_clean[-trainIndex, ]

# (2) Review ML data distributions
glimpse(train_data) # 5515 rows and 16 columns
glimpse(test_data) # 1376 rows and 16 columns
# Now data looks good to be processed by ML algorithm

# ----------------
# Machine Learning
# ----------------

# I am going to use most efficient library in R I have found so far - h20. 
# I use it to predict global sales of a game based on features like Genre, 
# Rating, Platform, Publisher, and other factors.
# h2o is an extremely fast, distributed ML that recommends best algorithms such 
# as Random Forests, Gradient Boosting Machines, and Deep Learning models.

# (1) Initialize h20 to use all cores
h2o.init(nthreads = -1)  

# (2) Convert train and test data sets to h2o frame
train_h2o <- as.h2o(train_data)
valid_h2o <- as.h2o(test_data)

# (3) Run AutoML to test multiple ML models quickly
aml <- h2o.automl(
  y = "Global_Sales",
  training_frame = train_h2o,
  max_runtime_secs = 300,  # 5 minute timeout
  seed = 123
)

# (4) Get best model from h20 analysis
best_model <- aml@leader

# (5) Predict data from test set based on ML Algorithm
h2o_pred <- predict(best_model, valid_h2o)

# (6) Calculate predictions based on test_data dataset and assess its RMSE
h2o_rmse <- RMSE(as.vector(h2o_pred), test_data$Global_Sales)
h2o_rmse # 0.005859286
# RMSE returns 0.0059, which is good considered we are working with global sales 
# prediction that are ranging in double digits, and mostly 0-1 range. 
# This is a great prediction result for a data set from Kaggle to predict global 
# sales of video games efficiently

#######################################################
####################### END ###########################
#######################################################