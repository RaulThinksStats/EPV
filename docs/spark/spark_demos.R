#template code for spark

#preliminaries
library(sparklyr)
library(tidyverse)
sc <- spark_connect(master = "local")

#data cleaning
import_iris <- copy_to(sc, iris, "spark_iris", overwrite = T)
partition_iris <- sdf_partition(import_iris, training = 0.5, testing = 0.5)
sdf_register(partition_iris, c("spark_iris_training", "spark_iris_test"))
tidy_iris <- tbl(sc, "spark_iris_training") %>% 
  select(Species, Petal_Length, Petal_Width)

#modeling
model_iris <- tidy_iris %>%
  ml_decision_tree(response = "Species", features = c("Petal_Length", "Petal_Width"))
test_iris <- tbl(sc, "spark_iris_test")
pred_iris <- sdf_predict(test_iris, model_iris) %>%
  collect

#visualization
pred_iris %>%
  inner_join(data.frame(prediction = 0:2,
  lab = model_iris$model.parameters$labels)) %>%
  ggplot(aes(Petal_Length, Petal_Width, col = lab)) + geom_point()

spark_disconnect(sc)


##example2: spark.rstudio.com

library(sparklyr)
library(dplyr)
library(nycflights13)
library(ggplot2)

sc <- spark_connect(master="local")
flights <- copy_to(sc, flights, "flights")
airlines <- copy_to(sc, airlines, "airlines")
src_tbls(sc)

select(flights, year:day, arr_delay, dep_delay)
filter(flights, dep_delay > 1000)
arrange(flights, desc(dep_delay))
summarise(flights, mean_dep_delay = mean(dep_delay))
mutate(flights, speed = distance / air_time * 60)


c1 <- filter(flights, day == 17, month == 5, carrier %in% c('UA', 'WN', 'AA', 'DL'))
c2 <- select(c1, year, month, day, carrier, dep_delay, air_time, distance)
c3 <- arrange(c2, year, month, day, carrier)
c4 <- mutate(c3, air_time_hours = air_time / 60)
c4

c4 <- flights %>%
  filter(month == 5, day == 17, carrier %in% c('UA', 'WN', 'AA', 'DL')) %>%
  select(carrier, dep_delay, air_time, distance) %>%
  arrange(carrier) %>%
  mutate(air_time_hours = air_time / 60)

c4 %>%
  group_by(carrier) %>%
  summarize(count = n(), mean_dep_delay = mean(dep_delay))

carrierhours <- collect(c4)

with(carrierhours, pairwise.t.test(air_time, carrier))
ggplot(carrierhours, aes(carrier, air_time_hours)) + geom_boxplot()



