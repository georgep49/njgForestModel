extensions [profiler matrix rnd vid csv]
__includes ["distributions.nls" "initialise.nls" "fileHandle.nls" "demographySetGet.nls" "demographyFuncs.nls" "helperFuncs.nls"]

globals
[
  ;; world dimensions
  world-size-patches ;; world-width * world-height defined in initialise.nls

  ;; text file names
  demography-files ;; NOT 100% how this works but should be defining the file with all the species info

  ;; various status variables
  abundances ;; How many of a species are present globally (I think) initiated in initialise.nls and the updated by update-abundances in demographySetGet.nls
  dbh-by-species ;; Appears to be max dbh of each species Initialised in initialise.nls and then updated by update-species-dbh in demographySetGet.nls
  age-by-species ;; Appears to be max age of each species Initialised in initialise.nls and then updated by update-species-age in demographySetGet.nls
  hgt-by-species ;; Appears to be max height of each species Initialised in initialise.nls and then updated by update-species-hgt in demographySetGet.nls
  mean-age-by-species ;;  Mean age for each species. Calculated identical to age-by-specie just updated by update-species-mean-age instead
  mean-hgt-by-species ;;  Mean height for each species. Calculated identical to hgt-by-specie just updated by update-species-mean-hgt instead
  BA-by-species ;; Bulk area (?). Calculated the same as above just updated with a unique equation in update-species-BA in demographySetGet.nls

  colour-list ;; List indicating the colour assocciated to each species. From demography file
  disturbFront ;; Disturbance front (i.e. new cells to be added to disturbed cells) updated by disturb-spread in demongraphyFuncs.nls
  disturbedArea ;; Total cells disturbed
  spp-list ;; List of ID numbers for each species defined on initialisation

  wgt-list ;; Weights list, a lookup list of the normal density for x from 0 to 1.0 used to compute the light env growth index much more quickly

  ;;seedlings-saplings Set of lists defining the probabilities of survival and transition for younger trees (Seem to be defined in demography_newTFKR.txt)
  seedling-survival
  sapling-survival
  seedling-transition
  seedling-mortality
  sapling-mortality


  ;; demography and species trait lists (Determines traits for each species) (Seem to be defined in demography_newTFKR.txt)
  max-hgt
  max-dbh
  max-age
  growth-form
  g-jabowa
  b2-jabowa
  b3-jabowa


  ;; tree-fern parameters
  a-tf-hgt ;; Some hard coded values presumably affecting tree fern height but no idea where values originate
  b-tf-hgt

  ;; All below variables seem to be defined in demography_newTFKR.txt
  shade-tolerance
  repro-height
  repro-age
  regen-height
  seed-prod ;; Value which seems to define amount of seeds produced based on a Poisson distribution
  ldd-dispersal-frac
  ldd-dispersal-dist
  gap-maker
  supp-tolerance ;; Suppression tolerance
  supp-mortality
  herbivory
  edge-response
  seedling-inhibition
  external-species ;; Chance species can invade from outside plot (outside model?) use a binomial process with p = external-species and n = max of 1% of grid cells or 1 equal vs 2 current abundance

  ;; No longer from demography_newTFKR.txt
  niche-breadth ;; Set as 0.3 in initialise.nls
  max-shade-dist ;; Set as 32 in initialise.nls

  ; initial conditions, seem to be defined by site-file (forest.txt)
  start-dbh
  start-dbh-sd
  seedlings-init
  saplings-init
  start-abund
  max-init-hgt

  ; restoration parameters
  saplings-to-plant ;; Appears to be a binary list corresponding to each species but unclear where it is from

  ; edge effect curve parameters
  edge-b1 ;; Value of 1
  edge-b0 ;; Value of 0 these seem extremely redundant


]

patches-own
[
  edge-weight ;; Edginess of patch, which impacts the amount of edge penalty affecting trees on that patch

  species ;; Think it is the ID of the species on that patch (NOT CERTAIN NEED TO ASK)
  prev-spp ;; Think its a record of the previous species on the patch

  nhbs ;; Neighbourhood surrounding each patch?????
  nhb-set ;; All patches contained in the neighbourhood of each patch??????
  height ;; Height of species on patch
  prev-height

  dbh
  age
  previous-growth  ;; list of the competition dependent growth penalty from previous five ticks

  nhb-height ;; Not sure what these two nhb measures are???
  nhb-light

  disturbed?
  expand?

  last-change-tick ;; Last tick in which a change occurred in a patch??
  n-change ;; Number of species changes that have occurred on a patch??

  seedlings ;; List of number of seedlings for each species in a patch
  saplings ;; List of number of saplings for each species in a patch
  seedling-density ;; Total number of seedlings in each patch
  sapling-density ;; Total number of saplings in each patch

  ; ground-cover weed parameters
  trad-cover ;; proportion of weed cover in a patch
  trad-inv ;; Tick at which weed spread to a patch???

  prop-ldd
]



to profile ;; Profile code using dedicated profile button
  ifelse profile_setup = TRUE
      [profiler:start
       repeat 5 [setup]
       profiler:stop]
      [setup
       profiler:start         ;; start profiling
       repeat 50 [ go ]       ;; run something you want to measure
       profiler:stop]          ;; stop profiling
  ifelse save_profile = TRUE
      [csv:to-file "profiler_data.csv" profiler:data] ;; Save results
      [print profiler:report] ;; view the results
  profiler:reset         ;; clear the data
end

;; NOTE `to setup` is contained in initialise.nls

to go

  if vid:recorder-status = "recording" [ vid:record-interface ] ;;Records the NetLogo interface view to the active recording.

    ;; Landscape-level disturbance?
    if disturbFreq > 0 [ lsp-disturbance ]

    ;; global / external dispersal?
    ;;TO DO  - turn on?
    ;;from-the-pool

    ;; Growth & background mortality
    ask patches with [species != 0]
    [
       grow
       set nhb-height get-nhb-height
    ]

    ;; Dispersal:: immediate and within landscape
    ask patches with [ species != 0 ]
    [
      let ra item (species - 1) repro-age
      let rh item (species - 1) repro-height
      if age >= ra and height >= rh [disperse species dbh]
    ]

    ;; Dispersal:: external to the landscape
    if external-rain? [external-ldd]

    ;; Herbivory
    if herbivory? [ herbivore-effect ]

    ;; Inhibition and macro-litterfall effect
    ask patches with [ species != 0 ]  [ thin-regenbank ]
    ask patches with [ species != 0 ]  [ macrolitterfall ]

    ;; Death
    ask patches with [ species != 0 ] [ death ]

    ;; Expand tree-falls?
    ask patches with [ expand? ]
    [
      expand-gap
      set expand? false
    ]

    ;; Update local light environment
    ask patches [
      set nhb-height get-nhb-height
      set nhb-light get-light-env (max max-hgt)
    ]

    ;; Empty cell capture
    ask patches with [species = 0]
    [
      capture-gap
    ]

    ;; Restoration by planting

    if restoration-planting? and ticks mod planting-frequency = 0
    [
       restoration-planting
    ]

    ;; Graphical display
    ifelse turtle-trees?
    [
      draw-trees
    ]
    [
      ask patches [colour-patch ]
    ]

   ;;seedlings-saplings regeneration
    ask patches
    [
      regenerate-patch-bank
      set seedling-density sum seedlings
      set sapling-density sum saplings
    ]

    let max-density max [sapling-density] of patches

    ;; Update abundance list
    update-abundances
    update-biometry

    tick
end

;; Initialise the patches

to colour-patch

   ;;ask turtles [set hidden? true]
   ifelse species = 0
   [
     set pcolor grey + 2
   ]
   [
     set pcolor (item (species - 1) colour-list)
   ]
end



;; Make a brand new tree for 'drawing'
to new-trees
  sprout 1
  [
    set hidden? not turtle-trees?
    set shape "circle 3"
    set color species
    set size 0.5 + (height / 15)
  ]
end

;; draw trees as circles (turtles)
to draw-trees

  ask patches [set pcolor black]

  ask turtles with [species != 0]
  [
    if hidden? = true [set hidden? false ]

    set color (item (species - 1) colour-list)
    set size 0.5 + (5 * dbh)
  ]
end

;; builds a list of patch-sets containing annuli of cells around patch
to build-sets

  let max-shell max-shade-dist / patch-grain     ;; so this is how far out to build the nhb too.

  let idx 0
  let d 1


  let d-set nobody
  let full-set nobody
  set nhb-set []

  while [ d <= max-shell]
  [
    ifelse d = 1
    [
        set d-set other patches in-radius d
        set full-set d-set
    ]
    [
         set d-set (other patches in-radius d) with [not member? self full-set]
         set full-set (patch-set full-set d-set)
    ]

    set nhb-set lput d-set nhb-set
    set d d + 1
    set idx idx + 1
  ]

end
@#$#@#$#@
GRAPHICS-WINDOW
331
10
859
539
-1
-1
20.0
1
10
1
1
1
0
0
0
1
0
25
0
25
1
1
1
ticks
30.0

BUTTON
3
10
72
43
Setup
setup
NIL
1
T
OBSERVER
NIL
S
NIL
NIL
1

BUTTON
82
11
145
44
Go
go
T
1
T
OBSERVER
NIL
G
NIL
NIL
1

BUTTON
154
10
224
43
Step
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
1164
10
1336
43
disturbFreq
disturbFreq
0
1
0.1
.005
1
NIL
HORIZONTAL

SLIDER
1164
48
1336
81
maxDisturbSize
maxDisturbSize
0
1
0.4
.01
1
NIL
HORIZONTAL

SWITCH
1339
12
1442
45
ddm
ddm
1
1
-1000

PLOT
8
56
278
206
Light field
Time
Light field
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot mean [nhb-light] of patches"
"pen-1" 1.0 0 -955883 true "" "plot min [nhb-light] of patches"
"pen-2" 1.0 0 -8630108 true "" "plot max [nhb-light] of patches"

SWITCH
1340
48
1465
81
turtle-trees?
turtle-trees?
1
1
-1000

SLIDER
1165
105
1337
138
n-species
n-species
8
8
8.0
0
1
NIL
HORIZONTAL

SLIDER
1166
143
1338
176
max-ticks
max-ticks
1000
10000
1000.0
250
1
NIL
HORIZONTAL

SLIDER
1164
190
1336
223
col-height
col-height
0
35
6.5
.25
1
NIL
HORIZONTAL

PLOT
8
387
276
557
Size structure (all species)
NIL
NIL
0.0
2.0
0.0
10.0
false
false
"set-histogram-num-bars 20\nset-plot-y-range 0 2500" "if plot? and ticks mod 10 = 0\n[ histogram [dbh] of patches with [species != 7] ]"
PENS
"default" 1.0 1 -16777216 true "" ""

PLOT
1167
617
1436
833
Age-DBH Relationship
Age
DBH
0.0
300.0
0.0
1.0
true
false
"" "if plot? and ticks mod 10 = 0\n[\n  plot-pen-reset \n  let N min (list count patches with [species != 0 and species != 7] 500)\n  ask n-of N patches with [species != 0  and species != 7]\n  [\n    set-plot-pen-color item (species - 1) colour-list\n    plotxy age dbh\n  ]\n]"
PENS
"default" 1.0 2 -16777216 true "" ""

TEXTBOX
1200
640
1403
662
500 randomly selected patches, every 10 yr
10
0.0
1

TEXTBOX
38
45
242
63
Light field (0 [high] to low [1]); max, mean, min
9
0.0
1

SWITCH
1344
148
1458
181
herbivory?
herbivory?
1
1
-1000

SWITCH
1346
183
1479
216
edge-effects?
edge-effects?
1
1
-1000

TEXTBOX
166
416
316
514
Tawa :: red\nPigeonwood :: yellow\nPukatea :: turquoise\nKawakawa :: blue\nMahoe :: pink\nRimu :: orange\nPonga :: dark green\nKanuka :: light blue
9
0.0
1

SWITCH
309
651
451
684
saplings-eaten?
saplings-eaten?
1
1
-1000

SWITCH
648
651
819
684
restoration-planting?
restoration-planting?
1
1
-1000

SLIDER
648
688
820
721
planting-frequency
planting-frequency
1
10
10.0
1
1
NIL
HORIZONTAL

SLIDER
1173
283
1345
316
edge-b2
edge-b2
0
1
0.0
.01
1
NIL
HORIZONTAL

TEXTBOX
1167
326
1364
368
as edge-b2 increases distance over which edge-effect occurs reduces
11
0.0
1

PLOT
1168
469
1368
619
Edge Curve
Distance
E(d)
0.0
10.0
0.0
1.0
true
false
"let x n-values (max-pycor / 2) [i -> i]\nforeach x\n[\n   i -> plotxy i edge-effect i\n]" ""
PENS
"default" 1.0 0 -16777216 true "" ""

SWITCH
1006
647
1109
680
plot?
plot?
1
1
-1000

INPUTBOX
23
728
274
788
demography-file
demography_newTFKR.txt
1
0
String

INPUTBOX
23
787
258
847
site-file
forest.txt
1
0
String

MONITOR
1167
229
1234
274
BA per ha
ba-per-ha
1
1
11

TEXTBOX
1487
93
1569
115
Dispersal from\noutside the world
9
15.0
1

SWITCH
1341
91
1474
124
external-rain?
external-rain?
1
1
-1000

MONITOR
1234
230
1314
275
Biggest tree
max [dbh] of patches
3
1
11

SWITCH
832
652
966
685
record-death?
record-death?
1
1
-1000

PLOT
13
568
282
718
DBH
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -2674135 true "" "plot item 0 BA-by-species"
"pen-1" 1.0 0 -1184463 true "" "plot item 1 BA-by-species"
"pen-2" 1.0 0 -8330359 true "" "plot item 2 BA-by-species"
"pen-3" 1.0 0 -14070903 true "" "plot item 3 BA-by-species"
"pen-4" 1.0 0 -2064490 true "" "plot item 4 BA-by-species"
"pen-5" 1.0 0 -955883 true "" "plot item 5 BA-by-species"
"pen-6" 1.0 0 -16110067 true "" "plot item 6 BA-by-species"

MONITOR
1314
231
1397
276
Mean tree size
mean [dbh] of patches
2
1
11

MONITOR
1400
230
1483
275
Median tree sizes
median [dbh] of patches
3
1
11

PLOT
8
205
278
387
Abundances
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -2674135 true "" "plot item 0 abundances"
"pen-1" 1.0 0 -1184463 true "" "plot item 1 abundances"
"pen-2" 1.0 0 -14835848 true "" "plot item 2 abundances"
"pen-3" 1.0 0 -14070903 true "" "plot item 3 abundances"
"pen-4" 1.0 0 -4757638 true "" "plot item 4 abundances"
"pen-5" 1.0 0 -955883 true "" "plot item 5 abundances"
"pen-6" 1.0 0 -7500403 true "" "plot count patches - sum abundances"
"pen-7" 1.0 0 -16375013 true "" "plot item 6 abundances"
"pen-8" 1.0 0 -8990512 true "" "plot item 7 abundances"

SLIDER
1169
377
1341
410
comp-multiplier
comp-multiplier
0
3
1.6
0.05
1
NIL
HORIZONTAL

SWITCH
1222
842
1349
875
record-prev?
record-prev?
1
1
-1000

SLIDER
1361
841
1533
874
recordprev-ticks
recordprev-ticks
0
2000
1000.0
100
1
NIL
HORIZONTAL

PLOT
1437
617
1688
833
Age-hgt Relationship
Age
Height
0.0
10.0
0.0
15.0
true
false
"" "if plot? and ticks mod 10 = 0\n[\n  plot-pen-reset \n  let N min (list count patches with [species = 7] 500)\n  ask n-of N patches with [species = 7]\n  [\n    set-plot-pen-color item (species - 1) colour-list\n    plotxy age height\n  ]\n]"
PENS
"default" 1.0 2 -16777216 true "" ""

TEXTBOX
1463
640
1613
658
500 randomly selected Tfs every 10 yr
8
0.0
1

PLOT
1377
408
1681
615
Tree fern height structure
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"set-histogram-num-bars 20\nset-plot-y-range 0 1000" ""
PENS
"default" 1.0 1 -16777216 true "set-histogram-num-bars 20\nset-plot-y-range 0 2000" "if plot? and ticks mod 10 = 0\n[ histogram [height] of patches with [species = 7] ]"

SLIDER
1391
349
1563
382
macro-litter-effect
macro-litter-effect
0
1
0.1
.01
1
NIL
HORIZONTAL

TEXTBOX
1395
304
1637
346
This is the elevated rate of sap mortality under life-form type 2 (tree-ferns, nikau, ...). It is prob of one sap being killed (pa).
11
0.0
1

SWITCH
310
695
451
728
ground-weeds?
ground-weeds?
0
1
-1000

SLIDER
465
693
637
726
trad-spread-local
trad-spread-local
0
1
0.2
.01
1
NIL
HORIZONTAL

SLIDER
464
733
636
766
trad-spread-long
trad-spread-long
0
.1
0.03
.001
1
NIL
HORIZONTAL

SLIDER
465
771
637
804
trad-growth
trad-growth
0
2.5
1.0
.1
1
NIL
HORIZONTAL

SLIDER
287
734
459
767
trad-init-cover
trad-init-cover
0
1
0.15
.005
1
NIL
HORIZONTAL

CHOOSER
307
770
445
815
trad-init-scenario
trad-init-scenario
"random" "clustered" "edges"
1

BUTTON
468
812
573
845
highlight-trad
ask patches with [ trad-cover > 0 ]\n[set pcolor white]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
286
820
458
853
smother-f
smother-f
0
1
0.2
.01
1
NIL
HORIZONTAL

CHOOSER
972
104
1156
149
ext-dispersal-scenario
ext-dispersal-scenario
"equal" "abundance"
0

SLIDER
970
62
1154
95
patch-grain
patch-grain
1
10
4.0
1
1
m
HORIZONTAL

SLIDER
970
23
1153
56
world-area
world-area
0
50
1.0
.25
1
ha
HORIZONTAL

BUTTON
233
10
307
43
Step 10
repeat 10 [go]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
973
170
1039
203
NIL
profile
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
973
204
1097
237
save_profile
save_profile
1
1
-1000

SWITCH
1041
169
1155
202
profile_setup
profile_setup
1
1
-1000

@#$#@#$#@
## WHAT IS IT?

This section could give a general understanding of what the model is trying to show or explain.

## HOW IT WORKS

This section could explain what rules the agents use to create the overall behavior of the model.

## HOW TO USE IT

This section could explain how to use the model, including a description of each of the items in the interface tab.

## THINGS TO NOTICE

This section could give some ideas of things for the user to notice while running the model.

## THINGS TO TRY

This section could give some ideas of things for the user to try to do (move sliders, switches, etc.) with the model.

## EXTENDING THE MODEL

This section could give some ideas of things to add or change in the procedures tab to make the model more complicated, detailed, accurate, etc.

## NETLOGO FEATURES

This section could point out any especially interesting or unusual features of NetLogo that the model makes use of, particularly in the Procedures tab.  It might also point out places where workarounds were needed because of missing features.

## RELATED MODELS

This section could give the names of models in the NetLogo Models Library or elsewhere which are of related interest.

## CREDITS AND REFERENCES

This section could contain a reference to the model's URL on the web if it has one, as well as any other necessary credits or references.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 3
false
0
Circle -7500403 false true 16 16 268

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

link
true
0
Line -7500403 true 150 0 150 300

link direction
true
0
Line -7500403 true 150 150 30 225
Line -7500403 true 150 150 270 225

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.2.2
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="GP-examples" repetitions="30" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>BA-by-species</metric>
    <metric>age-by-species</metric>
    <metric>dbh-by-species</metric>
    <metric>hgt-by-species</metric>
    <metric>abundances</metric>
    <enumeratedValueSet variable="external-rain?">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <steppedValueSet variable="macro-litter-effect" first="0.1" step="0.05" last="0.4"/>
  </experiment>
  <experiment name="baseline_herbivoria" repetitions="30" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>write-pattern</final>
    <timeLimit steps="1000"/>
    <metric>abundances</metric>
    <metric>age-by-species</metric>
    <metric>dbh-by-species</metric>
    <metric>hgt-by-species</metric>
    <enumeratedValueSet variable="demography-file">
      <value value="&quot;demography.txt&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="col-height">
      <value value="35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="restoration-planting?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="edge-effects?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maxDisturbSize">
      <value value="0.11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="turtle-trees?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herbivory?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ldd?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="disturbFreq">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="plot?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="edge-b2">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="site-file">
      <value value="&quot;Forest.txt&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ddm">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="saplings-eaten?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-ticks">
      <value value="2500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="planting-frequency">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-species">
      <value value="6"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="baseline_ldd" repetitions="30" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>write-pattern</final>
    <timeLimit steps="1000"/>
    <metric>abundances</metric>
    <metric>age-by-species</metric>
    <metric>dbh-by-species</metric>
    <metric>hgt-by-species</metric>
    <enumeratedValueSet variable="demography-file">
      <value value="&quot;demography.txt&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="col-height">
      <value value="35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="restoration-planting?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="edge-effects?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maxDisturbSize">
      <value value="0.11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="turtle-trees?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herbivory?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ldd?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="disturbFreq">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="plot?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="edge-b2">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="site-file">
      <value value="&quot;Forest.txt&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ddm">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="saplings-eaten?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-ticks">
      <value value="2500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="planting-frequency">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-species">
      <value value="6"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="edge-effect-basseline" repetitions="30" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>write-pattern</final>
    <timeLimit steps="1000"/>
    <metric>abundances</metric>
    <metric>age-by-species</metric>
    <metric>dbh-by-species</metric>
    <metric>hgt-by-species</metric>
    <enumeratedValueSet variable="demography-file">
      <value value="&quot;demography.txt&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="col-height">
      <value value="35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="restoration-planting?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="edge-effects?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maxDisturbSize">
      <value value="0.11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="turtle-trees?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herbivory?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ldd?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="disturbFreq">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="plot?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="edge-b2">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="site-file">
      <value value="&quot;Forest.txt&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ddm">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="saplings-eaten?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-ticks">
      <value value="2500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="planting-frequency">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-species">
      <value value="6"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="baseline_herbivoria_with_saplings" repetitions="30" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>write-pattern</final>
    <timeLimit steps="1000"/>
    <metric>abundances</metric>
    <metric>age-by-species</metric>
    <metric>dbh-by-species</metric>
    <metric>hgt-by-species</metric>
    <enumeratedValueSet variable="demography-file">
      <value value="&quot;demography.txt&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="col-height">
      <value value="35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="restoration-planting?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="edge-effects?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maxDisturbSize">
      <value value="0.11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="turtle-trees?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herbivory?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ldd?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="disturbFreq">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="plot?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="edge-b2">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="site-file">
      <value value="&quot;Forest.txt&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ddm">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="saplings-eaten?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-ticks">
      <value value="2500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="planting-frequency">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-species">
      <value value="6"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="herbivoria" repetitions="30" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>write-pattern</final>
    <timeLimit steps="1000"/>
    <metric>abundances</metric>
    <metric>age-by-species</metric>
    <metric>dbh-by-species</metric>
    <metric>hgt-by-species</metric>
    <enumeratedValueSet variable="demography-file">
      <value value="&quot;demography_herbivory_minus20.txt&quot;"/>
      <value value="&quot;demography_herbivory_plus20.txt&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="col-height">
      <value value="35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="restoration-planting?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="edge-effects?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maxDisturbSize">
      <value value="0.11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="turtle-trees?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herbivory?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ldd?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="disturbFreq">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="plot?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="edge-b2">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="site-file">
      <value value="&quot;Forest.txt&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ddm">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="saplings-eaten?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-ticks">
      <value value="2500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="planting-frequency">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-species">
      <value value="6"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="prueba" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>write-pattern</final>
    <timeLimit steps="1000"/>
    <metric>abundances</metric>
    <metric>age-by-species</metric>
    <metric>dbh-by-species</metric>
    <metric>hgt-by-species</metric>
    <metric>mean-age-by-species</metric>
    <metric>BA-by-species</metric>
    <metric>mean-hgt-by-species</metric>
    <enumeratedValueSet variable="demography-file">
      <value value="&quot;demography.txt&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="col-height">
      <value value="35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="restoration-planting?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="edge-effects?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maxDisturbSize">
      <value value="0.11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="turtle-trees?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herbivory?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ldd?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="disturbFreq">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="plot?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="edge-b2">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="site-file">
      <value value="&quot;Forest.txt&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ddm">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="saplings-eaten?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-ticks">
      <value value="2500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="planting-frequency">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-species">
      <value value="6"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="sensitivity_narkis" repetitions="30" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>write-pattern</final>
    <timeLimit steps="1000"/>
    <metric>abundances</metric>
    <metric>age-by-species</metric>
    <metric>dbh-by-species</metric>
    <metric>hgt-by-species</metric>
    <enumeratedValueSet variable="plot?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="disturbFreq">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-species">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="edge-effects?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="demography-file">
      <value value="&quot;demography_seedling_survival_minus20.txt&quot;"/>
      <value value="&quot;demography_seedling_survival_plus20.txt&quot;"/>
      <value value="&quot;demography_seedling_transition_minus20.txt&quot;"/>
      <value value="&quot;demography_seedling_transition_plus20.txt&quot;"/>
      <value value="&quot;demography_shade_tol_minus20.txt&quot;"/>
      <value value="&quot;demography_shade_tol_plus20.txt&quot;"/>
      <value value="&quot;demography_supp_mort_minus20.txt&quot;"/>
      <value value="&quot;demography_supp_mort_plus20.txt&quot;"/>
      <value value="&quot;demography_supp_tol_minus20.txt&quot;"/>
      <value value="&quot;demography_supp_tol_plus20.txt&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="saplings-eaten?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="site-file">
      <value value="&quot;Forest.txt&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="planting-frequency">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maxDisturbSize">
      <value value="0.11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="col-height">
      <value value="35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="edge-b2">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ldd?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="turtle-trees?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ddm">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-ticks">
      <value value="2500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="restoration-planting?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herbivory?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="fenced_edge_ldd" repetitions="30" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>write-pattern</final>
    <timeLimit steps="1000"/>
    <metric>abundances</metric>
    <metric>age-by-species</metric>
    <metric>dbh-by-species</metric>
    <metric>hgt-by-species</metric>
    <metric>mean-age-by-species</metric>
    <metric>BA-by-species</metric>
    <metric>mean-hgt-by-species</metric>
    <enumeratedValueSet variable="plot?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="disturbFreq">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-species">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="edge-effects?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="demography-file">
      <value value="&quot;demography.txt&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="site-file">
      <value value="&quot;Fenced.txt&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="planting-frequency">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maxDisturbSize">
      <value value="0.11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="col-height">
      <value value="35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="edge-b2">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ldd?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="turtle-trees?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ddm">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-ticks">
      <value value="2500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="restoration-planting?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herbivory?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="baseline_pattern" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <final>write-pattern</final>
    <timeLimit steps="2000"/>
    <enumeratedValueSet variable="plot?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="disturbFreq">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-species">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="edge-effects?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="demography-file">
      <value value="&quot;demography.txt&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="saplings-eaten?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="site-file">
      <value value="&quot;Forest.txt&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="planting-frequency">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maxDisturbSize">
      <value value="0.11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="col-height">
      <value value="35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="edge-b2">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ldd?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="turtle-trees?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ddm">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-ticks">
      <value value="2500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="restoration-planting?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herbivory?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="forest_scenario_competition_multiplier" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <metric>abundances</metric>
    <metric>dbh-by-species</metric>
    <metric>BA-by-species</metric>
    <metric>bank-tawa</metric>
    <metric>bank-pigeonwood</metric>
    <metric>bank-pukatea</metric>
    <metric>bank-kawakawa</metric>
    <metric>bank-mahoe</metric>
    <metric>bank-rimu</metric>
    <enumeratedValueSet variable="plot?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="disturbFreq">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-species">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="edge-effects?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="demography-file">
      <value value="&quot;demography.txt&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="site-file">
      <value value="&quot;Forest.txt&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="planting-frequency">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maxDisturbSize">
      <value value="0.11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="col-height">
      <value value="35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="edge-b2">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ldd?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="turtle-trees?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ddm">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-ticks">
      <value value="800"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="restoration-planting?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herbivory?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="comp-multiplier">
      <value value="1.05"/>
      <value value="1.1"/>
      <value value="1.15"/>
      <value value="1.2"/>
      <value value="1.25"/>
      <value value="1.3"/>
      <value value="1.35"/>
      <value value="1.4"/>
      <value value="1.45"/>
      <value value="1.5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="fenced_scenario" repetitions="30" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <final>write-pattern</final>
    <timeLimit steps="500"/>
    <metric>abundances</metric>
    <metric>dbh-by-species</metric>
    <metric>BA-by-species</metric>
    <metric>bank-tawa</metric>
    <metric>bank-pigeonwood</metric>
    <metric>bank-pukatea</metric>
    <metric>bank-kawakawa</metric>
    <metric>bank-mahoe</metric>
    <metric>bank-rimu</metric>
    <enumeratedValueSet variable="plot?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="disturbFreq">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-species">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="edge-effects?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="demography-file">
      <value value="&quot;demography.txt&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="site-file">
      <value value="&quot;fenced.txt&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="planting-frequency">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maxDisturbSize">
      <value value="0.11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="col-height">
      <value value="35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="edge-b2">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ldd?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="turtle-trees?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ddm">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-ticks">
      <value value="2500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="restoration-planting?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herbivory?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="unfenced_scenario" repetitions="30" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <final>write-pattern</final>
    <timeLimit steps="500"/>
    <metric>abundances</metric>
    <metric>dbh-by-species</metric>
    <metric>BA-by-species</metric>
    <metric>bank-tawa</metric>
    <metric>bank-pigeonwood</metric>
    <metric>bank-pukatea</metric>
    <metric>bank-kawakawa</metric>
    <metric>bank-mahoe</metric>
    <metric>bank-rimu</metric>
    <enumeratedValueSet variable="plot?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="disturbFreq">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-species">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="edge-effects?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="demography-file">
      <value value="&quot;demography.txt&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="site-file">
      <value value="&quot;unfenced.txt&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="planting-frequency">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maxDisturbSize">
      <value value="0.11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="col-height">
      <value value="35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="edge-b2">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ldd?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="turtle-trees?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ddm">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-ticks">
      <value value="2500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="restoration-planting?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herbivory?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="saplings-eaten?">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="forest_scenario_competition_multiplier_rimu_with_original_parameters" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <metric>abundances</metric>
    <metric>dbh-by-species</metric>
    <metric>BA-by-species</metric>
    <metric>bank-tawa</metric>
    <metric>bank-pigeonwood</metric>
    <metric>bank-pukatea</metric>
    <metric>bank-kawakawa</metric>
    <metric>bank-mahoe</metric>
    <metric>bank-rimu</metric>
    <enumeratedValueSet variable="plot?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="disturbFreq">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-species">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="edge-effects?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="demography-file">
      <value value="&quot;demography.txt&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="site-file">
      <value value="&quot;Forest.txt&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="planting-frequency">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maxDisturbSize">
      <value value="0.11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="col-height">
      <value value="35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="edge-b2">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ldd?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="turtle-trees?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ddm">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-ticks">
      <value value="800"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="restoration-planting?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herbivory?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="comp-multiplier">
      <value value="1.6"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="forest_scenario_tree_replacement" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <enumeratedValueSet variable="plot?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="disturbFreq">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-species">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="edge-effects?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="demography-file">
      <value value="&quot;demography.txt&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="site-file">
      <value value="&quot;Forest.txt&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="planting-frequency">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maxDisturbSize">
      <value value="0.11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="col-height">
      <value value="35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="edge-b2">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ldd?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="turtle-trees?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ddm">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-ticks">
      <value value="800"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="restoration-planting?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herbivory?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="comp-multiplier">
      <value value="1.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="recordprev-ticks">
      <value value="100"/>
      <value value="200"/>
      <value value="300"/>
      <value value="400"/>
      <value value="500"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="300"/>
    <metric>abundances</metric>
    <enumeratedValueSet variable="disturbFreq">
      <value value="0"/>
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-species">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="recordprev-ticks">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="trad-init-scenario">
      <value value="&quot;clustered&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="trad-spread-long">
      <value value="1.0E-4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ddm">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="smother-f">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="external-rain?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-ticks">
      <value value="800"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="edge-effects?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="edge-b2">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="turtle-trees?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="restoration-planting?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="record-prev?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="demography-file">
      <value value="&quot;demography_newTFKR.txt&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="saplings-eaten?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="site-file">
      <value value="&quot;forest.txt&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="record-death?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="trad-init-cover">
      <value value="0.025"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="trad-spread-local">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="plot?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ground-weeds?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="planting-frequency">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="herbivory?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="col-height">
      <value value="35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="comp-multiplier">
      <value value="1.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="macro-litter-effect">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="maxDisturbSize">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="trad-growth">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ext-dispersal-scenario">
      <value value="&quot;equal&quot;"/>
      <value value="&quot;abundance&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="setup_scale_profile" repetitions="2" runMetricsEveryStep="true">
    <setup>profiler:reset
profiler:start
       repeat 15 [setup]
profiler:stop</setup>
    <go>stop</go>
    <metric>profiler:data</metric>
    <steppedValueSet variable="world-area" first="2" step="2" last="40"/>
  </experiment>
  <experiment name="go_scale_profile" repetitions="1" runMetricsEveryStep="false">
    <setup>profiler:reset
setup
profiler:start</setup>
    <go>go</go>
    <final>profiler:stop</final>
    <timeLimit steps="2"/>
    <metric>profiler:data</metric>
    <steppedValueSet variable="world-area" first="2" step="2" last="40"/>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
