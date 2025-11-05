library(tidyverse)
library(IPEDSR)
library(DBI)
library(broom)
library(lme4)
library(broom.mixed)

count_control <- function(df, char){
  df |>
    distinct(UNITID) |>
    inner_join(char |> select(UNITID, Control), by = "UNITID") |>
    count(Control) %>% # for the . operator
    # add total row
    bind_rows(
      tibble(Control = "Total",
             n = sum(.$n))
    ) |>
    arrange(Control)
}

idbc <- IPEDSR::get_ipeds_connection()

# characteristics of colleges existing in 2022
char <- IPEDSR::get_characteristics(idbc, labels = FALSE) |>
  select(UNITID, INSTNM, Control = CONTROL, Level = ICLEVEL, MedSchool = MEDICAL) |>
  mutate(Control = case_match(Control,
                              1 ~ "Public",
                              2 ~ "Private not-for-profit",
                              3 ~ "Private for-profit",
                              TRUE ~ NA_character_))

count_control(char, char)

# restrict to traditional 4-year colleges
trad_college <- char |>
  filter(Level == 1,  # restrict to 4-year institutions
         MedSchool != 1, # exclude med schools
         Control %in% c("Public", "Private not-for-profit")) |>   # exclude for-profits
  select(UNITID, Name = INSTNM, Control)

count_control(trad_college, char)

############### enrollment ########################
enroll <- IPEDSR::ipeds_get_enrollment(idbc, StudentTypeCode = c(22, # UGFT
                                                                 32, # GFT
                                                                 42, # UGPT
                                                                 52)) |>  # GPT
  select(UNITID, Year, N = Total, SType = StudentType) |>
  spread(SType, N, fill = 0) |>
  rename(FTG = 3, FTUG = 4, PTG = 5, PTUG = 6)

enroll |>
  count_control(trad_college)

# undergrad enrollment over time
enroll |>
  inner_join(trad_college) |>
  group_by(Year, Control) |>
  summarize(FTUG = median(FTUG, na.rm = TRUE)) |>
  ggplot(aes(x = Year, y = FTUG, color = Control )) +
  geom_point() +
  geom_line() +
  theme_bw()

# grad enrollment over time
enroll |>
  inner_join(trad_college) |>
  group_by(Year, Control) |>
  summarize(FTG = median(FTG, na.rm = TRUE)) |>
  ggplot(aes(x = Year, y = FTG, color = Control )) +
  geom_point() +
  geom_line() +
  theme_bw()

############### retention ########################
retention <- IPEDSR::get_retention(idbc) |>
             mutate(remove_me = if_else(Retention == 0 |
                                        Cohort_size < 100,
                                        1, 0)) |>
             group_by(UNITID) |>
             mutate(remove = max(remove_me)) |>
             ungroup() |>
             filter(!remove_me) |>
             select(-remove_me)

count_control(retention, trad_college)

retention |>
  inner_join(trad_college, by = "UNITID") |>
  ggplot(aes(x = Retention, fill = Control)) +
  geom_density(alpha = .4) +
  theme_bw()

retention |>
  inner_join(trad_college) |>
  group_by(Year, Control) |>
  summarize(Retention = median(Retention, na.rm = TRUE)) |>
  ggplot(aes(x = Year, y = Retention, color = Control )) +
  geom_point() +
  geom_line() +
  theme_bw()

############# Tuition ############

tuition <- IPEDSR::get_tuition(idbc)

tuition |>
  count_control(trad_college)

tuition |>
  inner_join(trad_college) |>
  group_by(Year, Control) |>
  summarize(Tuition = median(Tuition, na.rm = TRUE)) |>
  ggplot(aes(x = Year, y = Tuition, color = Control )) +
  geom_point() +
  geom_line() +
  theme_bw()

############## net tuition revenue ################

finances <- get_finances(idbc) |>
       select(UNITID, Year, Net_tuition_revenue, Inst_aid, Cost_instruction_salary)

finances |>
  count_control(trad_college)

# publics
finances |>
  inner_join(char) |>
  inner_join(retention) |>
  mutate(NTRcs = Net_tuition_revenue / Cohort_size) |>
  filter(Control == "Public",
         NTRcs < 2e5) |>
  ggplot(aes(x = Retention, y = NTRcs )) +
  geom_point(alpha = .1) +
  geom_smooth(method = "lm", se = FALSE) +
  theme_bw() +
  facet_wrap(~Year)

# privates
finances |>
  inner_join(char) |>
  inner_join(retention) |>
  mutate(NTRcs = Net_tuition_revenue / Cohort_size) |>
  filter(Control != "Public",
         NTRcs < 2e5) |>
  ggplot(aes(x = Retention, y = NTRcs )) +
  geom_point(alpha = .1) +
  geom_smooth(method = "lm", se = FALSE) +
  theme_bw() +
  facet_wrap(~Year)

############## financial aid ################
fa <- IPEDSR::get_fa_info(idbc) |>
      filter(!is.na(Avg_inst_aid))

fa |>
  count_control(trad_college)

# compare median private tuition and institutional aid over time
tuition |>
  inner_join(trad_college) |>
  inner_join(fa) |>
  group_by(Year, Control) |>
  summarize(Tuition = median(Tuition, na.rm = TRUE),
            InstAid = median(Avg_inst_aid, na.rm = TRUE)) |>
  gather(key = "type", value = "value", Tuition, InstAid) |>
  ggplot(aes(x = Year, y = value, color = type )) +
  geom_point() +
  geom_line() +
  theme_bw() +
  facet_wrap(~Control, scales = "free_y")

###################################################
############## Computing NTRs #####################
###################################################

##############################################################
# Method 1. Divide total NTR by total equivalent enrollment
# this assumes undergrads and grads pay the same amount
# and is averaged over new students AND returners
##############################################################

ntrs1 <- finances |>
  inner_join(enroll) |>
  mutate(
    N_equiv = FTUG + FTG + PTUG / 3 + PTG / 3,
    ntrs1 = Net_tuition_revenue / N_equiv
  ) |>
  select(UNITID, Year, ntrs1) |>
  na.omit()

count_control(ntrs1, trad_college)

##############################################################
# Method 2. Tuition - Avg institutional aid for entering class
##############################################################
ntrs2 <- tuition |>
  inner_join(trad_college) |>
  inner_join(fa) |>
  mutate(ntrs2 = Tuition - Avg_inst_aid) |>
  select(UNITID, Year, ntrs2) |>
  na.omit()

count_control(ntrs2, trad_college)

# compare the two methods
# publics
ntrs1 |>
  inner_join(ntrs2, by = c("UNITID", "Year")) |>
  inner_join(char, by = "UNITID") |>
  filter(Control == "Public",
         ntrs1 < 1e5) |>
  ggplot(aes(x = ntrs1, y = ntrs2, color = Year)) +
  geom_point(alpha = 0.1) +
  geom_abline(slope = 1, intercept = 0, color = "red") +
  facet_wrap(~Year)

# privates
ntrs1 |>
  inner_join(ntrs2, by = c("UNITID", "Year")) |>
  inner_join(char, by = "UNITID") |>
  filter(Control != "Public",
         ntrs1 < 1e5) |>
  ggplot(aes(x = ntrs1, y = ntrs2, color = Year)) +
  geom_point(alpha = 0.1) +
  geom_abline(slope = 1, intercept = 0, color = "red") +
  facet_wrap(~Year)

##############################################################
# Method 3. Tuition - total aid from finances / undergrad enrollment
# assumes all aid goes to FT undergrads
##############################################################

ntrs3 <-  tuition |>
  inner_join(trad_college) |>
  inner_join(finances) |>
  inner_join(enroll) |>
  mutate(ntrs3 = Tuition - Inst_aid/FTUG)  |>
  select(UNITID, Year, ntrs3) |>
  na.omit()

# compare to ntrs2
# publics
ntrs3 |>
  inner_join(ntrs2, by = c("UNITID", "Year")) |>
  inner_join(char, by = "UNITID") |>
  filter(Control == "Public",
         ntrs2 < 1e5,
         ntrs3 < 1e5,
         ntrs3 > -1e4) |>
  ggplot(aes(x = ntrs3, y = ntrs2, color = Year)) +
  geom_point(alpha = 0.1) +
  geom_abline(slope = 1, intercept = 0, color = "red") +
  facet_wrap(~Year)

# privates
ntrs3 |>
  inner_join(ntrs2, by = c("UNITID", "Year")) |>
  inner_join(char, by = "UNITID") |>
  filter(Control != "Public",
         ntrs2 < 1e5,
         ntrs3 < 1e5,
         ntrs3 > -1e4) |>
  ggplot(aes(x = ntrs3, y = ntrs2, color = Year)) +
  geom_point(alpha = 0.1) +
  geom_abline(slope = 1, intercept = 0, color = "red") +
  facet_wrap(~Year)


##############################################################
# Title-IV students, net cost of attendance
##############################################################
pell <- fa |>
  select(Year, UNITID, Avg_net_price, N_fall_cohort, Percent_PELL, ends_with("k")) |>
  na.omit() |>
  mutate(N_all = round(N_fall_cohort*Percent_PELL)) |>
  select(-N_fall_cohort, -Percent_PELL) |>
  gather(key = "variable", value = "value", -Year, -UNITID) |>
  mutate(variable = str_remove(variable, "Avg_net_")) |>
  separate(variable, into = c("type","income"), sep = "_") |>
  replace_na(list(income = "all")) |>
  na.omit() |>
#  mutate(income = as.numeric(str_remove(income, "k"))) |>
  pivot_wider(names_from = type, values_from = value)  |>
  mutate(income = factor(income,
                         levels=c("0k", "30k", "48k", "75k", "110k", "all"),
                         ordered = TRUE))

count_control(pell, trad_college)

# price by year
pell |>
  filter(income != "all") |>
  inner_join(trad_college) |>
  filter(Control != "Public") |>
  group_by(Year, Control, income) |>
  summarize(
    mean_price = weighted.mean(price, weights = N, na.rm = TRUE)
  ) |>
  ggplot(aes(x = Year, y = mean_price, color = income, group = income)) +
  geom_point() +
  geom_line() +
  theme_bw()

# average price compared to NTRs2

pell |>
  inner_join(trad_college) |>
  filter(Control != "Public", income == "all") |>
  inner_join(ntrs2) |>
  ggplot(aes(x = price, y = ntrs2, color = Year)) +
  geom_point(alpha = 0.1) +
  geom_smooth(method = "lm", se = FALSE) +
  theme_bw()

######################################################
# Method 4. Model-based adjustment ###################
######################################################

model_data <- enroll |>
              inner_join(finances, by = c("UNITID", "Year")) |>
              inner_join(trad_college) |>
              mutate(N = FTUG + FTG + PTUG/3 + PTG/3,
                     log_salary = log(Cost_instruction_salary/N),
                     NTRs = Net_tuition_revenue/N,
                     FTUGp = FTUG/N,
                     FTGp  = FTG/N,
                     PTGp  = PTG/N,
                     UG_equiv = FTUG + PTUG / 3,
                     G_equiv  = FTG + PTG / 3,
                     Total_equiv = UG_equiv + G_equiv,
                     prop_grad = G_equiv / Total_equiv,
                     prop_pt   = (PTUG + PTG) / (FTUG + PTUG + FTG + PTG),
                     ntr_per_ug = Net_tuition_revenue / UG_equiv,
                     log_ntr_per_ug = log(ntr_per_ug)) |>
              filter( UG_equiv > 0,
                      ntr_per_ug > 0)

count_control(model_data, trad_college)

# Function to apply year-specific model to each school its data
# Fit separate weighted models for each year
hierarchical_model <-  lmer(
  log(ntr_per_ug) ~ prop_grad + factor(Year) + (1 + prop_grad | UNITID),
  #  weights = Total_equiv,
  data = model_data
)

summary(hierarchical_model)

unitid_effects <- broom.mixed::tidy(hierarchical_model, effects = "ran_vals") |>
  filter(term == "prop_grad") |>
  rename(b_grad = estimate) |>
  select(UNITID = level, b_grad) |>
  mutate(UNITID = as.integer(UNITID))

ntrs4 <- model_data |>
  left_join(unitid_effects, by = "UNITID") |>
  mutate( bias = exp(-b_grad * prop_grad),
         ntrs4 = ntr_per_ug * bias) |>
  select(UNITID, Year, bias, ntrs4)


# sanity check. ntrs4 should be close to ntrs1 for schools with
# small grad programs
ntrs4 |>
  inner_join(model_data |> select(UNITID, Year, Control, prop_grad), by = c("UNITID", "Year")) |>
  inner_join(ntrs1, by = c("UNITID", "Year")) |>
  filter(ntrs1 < 1e5,
         ntrs4  < 1e5,
         prop_grad < 0.1) |>
  ggplot(aes(x = ntrs1, y = ntrs4)) +
  geom_point(alpha = 0.1) +
  geom_abline(slope = 1, intercept = 0, color = "red") +
  facet_wrap(~Year) +
  theme_bw()

# compare ntrs1 and ntrs4 by grad school proportion
ntrs4 |>
  inner_join(ntrs1, by = c("UNITID", "Year")) |>
  filter(ntrs1 < 1e5,
         ntrs4  < 1e5,
         Year > max(Year) - 5) |>
  inner_join(model_data |> select(UNITID, Year, Control, prop_grad), by = c("UNITID", "Year")) |>
  mutate(prop_grad = case_when(
    prop_grad < 0.1 ~ "<10%",
    prop_grad < 0.3 ~ "10-30%",
    prop_grad < 0.5 ~ "30-50%",
    TRUE ~ "50%+"
  )) |>
  group_by(UNITID, prop_grad) |>
  summarize(
    ntrs1 = mean(ntrs1, na.rm = TRUE),
    ntrs4 = mean(ntrs4, na.rm = TRUE),
    Control = first(Control)
  ) |>
  ggplot(aes(x = ntrs1, y = ntrs4)) +
  geom_point(alpha = 0.3) +
  geom_abline(slope = 1, intercept = 0, color = "red") +
  facet_grid(prop_grad ~ Control) +
  theme_bw()

# compare to ntrs2
ntrs4 |>
  inner_join(ntrs2, by = c("UNITID", "Year")) |>
  filter(ntrs2 < 1e5,
         ntrs4  < 1e5,
         Year > max(Year) - 5) |>
  inner_join(model_data |> select(UNITID, Year, Control, prop_grad), by = c("UNITID", "Year")) |>
  mutate(prop_grad = case_when(
    prop_grad < 0.1 ~ "<10%",
    prop_grad < 0.3 ~ "10-30%",
    prop_grad < 0.5 ~ "30-50%",
    TRUE ~ "50%+"
  )) |>
  group_by(UNITID, prop_grad) |>
  summarize(
    ntrs2 = mean(ntrs2, na.rm = TRUE),
    ntrs4 = mean(ntrs4, na.rm = TRUE),
    Control = first(Control)
  ) |>
  ggplot(aes(x = ntrs2, y = ntrs4)) +
  geom_point(alpha = 0.3) +
  geom_abline(slope = 1, intercept = 0, color = "red") +
  facet_grid(prop_grad ~ Control) +
  theme_bw()

