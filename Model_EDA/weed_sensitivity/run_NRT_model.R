library(nlrx)
library(future)
netlogopath <- file.path("C:/Program Files/NetLogo 6.2.2")
modelpath <- file.path("C:/Users/simpk/Dropbox/Professional/Academic/Uni Auckland/NRT/njgForestModel/TF-150921-version62.nlogo")
outpath <- file.path("C:/Users/simpk/Dropbox/Professional/Academic/Uni Auckland/NRT/njgForestModel/Model_EDA/weed_sensitivity")

nl <- nl(nlversion = "6.2.2",
         nlpath = netlogopath,
         modelpath = modelpath,
         jvmmem = 1024)


nl@experiment <- experiment(expname="weed_impact",
                            outpath=outpath,
                            repetition=5,
                            tickmetrics="true",
                            idsetup="setup",
                            idgo="go",
                            runtime=1000,
                            evalticks=seq(100, 1000, by = 100),
                            metrics=c("BA-by-species", 
                                      "age-by-species", 
                                      "dbh-by-species",
                                      "hgt-by-species",
                                      "abundances"),
                            variables = list("ground-weeds?" = list(values=c("true", "false"))),
                            constants = list("world-area" = 1,
                                             "patch-grain" = 4))


nl@simdesign <- simdesign_distinct(nl=nl,
                                   nseeds=3)

# Evaluate nl object:
eval_variables_constants(nl)
print(nl)

# Run all simulations (loop over all siminputrows and simseeds)
plan(multisession)
results <- run_nl_all(nl)

# Attach results to nl object:
setsim(nl, "simoutput") <- results

# Write output to outpath of experiment within nl
write_simoutput(nl)
