library(nlrx)
library(future)
netlogopath <- file.path("C:/Program Files/NetLogo 6.2.2")
modelpath <- file.path("C:/Users/simpk/Dropbox/Professional/Academic/Uni Auckland/NRT/njgForestModel/TF-150921-version62.nlogo")
outpath <- file.path("C:/Users/simpk/Dropbox/Professional/Academic/Uni Auckland/NRT/njgForestModel/Model_EDA/weed_sensitivity")

nl <- nl(nlversion = "6.2.2",
         nlpath = netlogopath,
         modelpath = modelpath,
         jvmmem = 1024)

nl@experiment <- experiment(expname="weed_sensitivity",
                            outpath=outpath,
                            repetition=3,
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
                            variables = list('trad-init-cover' = list(min=0, max=1, step=0.5, qfun="qunif"),
                                             "smother-f" = list(min=0, max=1, step=0.5, qfun="qunif"),
                                             "trad-spread-local" = list(min=0, max=1, step=0.5, qfun="qunif"),
                                             "trad-spread-long" = list(min=0, max=1, step=0.5, qfun="qunif"),
                                             "trad-growth" = list(min=0, max=2.5, step=1.25, qfun="qunif")),
                            constants = list('ground-weeds?' = 'true',
                                             "world-area" = 1,
                                             "patch-grain" = 4))


nl@simdesign <- simdesign_ff(nl=nl,
                             nseeds=2)

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

# Do further analysis:
analyze_nl(nl)
