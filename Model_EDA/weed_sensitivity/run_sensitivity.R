library(nlrx)
library(future)
netlogopath <- file.path("C:/Program Files/NetLogo 6.2.2")
modelpath <- file.path("C:/Users/simpk/Dropbox/Professional/Academic/Uni Auckland/NRT/njgForestModel/TF-150921-version62.nlogo")
outpath <- file.path("C:/Users/simpk/Dropbox/Professional/Academic/Uni Auckland/NRT/njgForestModel/Model_EDA/weed_sensitivity")

nl <- nl(nlversion = "6.2.2",
         nlpath = netlogopath,
         modelpath = modelpath,
         jvmmem = 1024)

# nl@experiment <- experiment(expname="wolf-sheep",
#                             outpath=outpath,
#                             repetition=1,
#                             tickmetrics="true",
#                             idsetup="setup",
#                             idgo="go",
#                             runtime=20,
#                             evalticks=15,
#                             metrics=c("count sheep", "count wolves", "count patches with [pcolor = green]"),
#                             variables = list('initial-number-sheep' = list(min=50, max=100, step=10, qfun="qunif"),
#                                              "initial-number-wolves" = list(min=50, max=150, step=10, qfun="qunif")),
#                             constants = list("model-version" = "\"sheep-wolves-grass\"",
#                                              "grass-regrowth-time" = 30,
#                                              "sheep-gain-from-food" = 4,
#                                              "wolf-gain-from-food" = 20,
#                                              "sheep-reproduce" = 4,
#                                              "wolf-reproduce" = 5,
#                                              "show-energy?" = "false"))

nl@experiment <- experiment(expname="weed_sensitivity",
                            outpath=outpath,
                            repetition=1,
                            tickmetrics="false",
                            idsetup="setup",
                            idgo="go",
                            runtime=500,
                            evalticks=500,
                            metrics=c("BA-by-species", 
                                      "age-by-species", 
                                      "dbh-by-species",
                                      "hgt-by-species",
                                      "abundances"),
                            variables = list('trad-init-cover' = list(min=0, max=1, step=0.2, qfun="qunif"),
                                             "smother-f" = list(min=0, max=1, step=0.2, qfun="qunif"),
                                             "trad-spread-local" = list(min=0, max=1, step=0.2, qfun="qunif"),
                                             "trad-spread-long" = list(min=0, max=1, step=0.2, qfun="qunif"),
                                             "trad-growth" = list(min=0, max=2.5, step=0.5, qfun="qunif")),
                            constants = list())

# nl@simdesign <- simdesign_morris(nl=nl,
#                                  morristype="oat",
#                                  morrislevels=4,
#                                  morrisr=1000,
#                                  morrisgridjump=2,
#                                  nseeds=5)


nl@simdesign <- simdesign_ff(nl=nl,
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

# Do further analysis:
analyze_nl(nl)
