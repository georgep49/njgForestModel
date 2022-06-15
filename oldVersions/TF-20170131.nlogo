extensions [profiler matrix rnd]
__includes ["distributions.nls" "initial.nls"]

globals
[
  ;; text file names

  demography-files

  ;; various status variables
  abundances
  dbh-by-species
  age-by-species
  hgt-by-species
  mean-age-by-species
  mean-hgt-by-species
  BA-by-species
  worldSize
  patch-grain

  colour-list
  disturbFront
  disturbedArea
  spp-list

  wgt-list

  ;;seedlings-saplings
  seedling-survival
  sapling-survival
  seedling-transition
  seedling-mortality
  sapling-mortality


  ;; demography and species trait lists
  ;;colour-list
  max-hgt
  max-dbh
  max-age
  growth-form
  g-jabowa
  b2-jabowa
  b3-jabowa


  ;; tree-fern parameters

  a-tf-hgt
  b-tf-hgt

  shade-tolerance
  repro-age
  regen-height
  seed-prod
  ldd-dispersal-frac
  ldd-dispersal-dist
  gap-maker
  supp-tolerance
  supp-mortality
  herbivory
  edge-response
  external-species


  niche-breadth
  max-shade-dist

  ; initial conditions
  start-dbh
  start-dbh-sd
  seedlings-init
  saplings-init
  start-abund

  ; restoration parameters
  saplings-to-plant

  ; edge effect curve parameters
  edge-b1
  edge-b0

]

patches-own
[
  edge-weight

  species
  prev-spp


  nhbs
  nhb-set
  height
  prev-height


  dbh
  age
  previous-growth  ; list of the competition dependent growth penalty from previous five ticks

  nhb-height
  nhb-light

  disturbed?
  expand?

  last-change-tick
  n-change


  seedlings
  saplings
  seedling-density
  sapling-density

  prop-ldd
]

to make-movie
  ;; prompt user for movie location
  user-message "First, save your new movie file (choose a name ending with .mov)"
  let path user-new-file
  if not is-string? path [ stop ]  ;; stop if user canceled

setup
movie-start path
movie-grab-view ;; show the initial state
repeat 2000
[ go
  movie-grab-view ]
movie-close
user-message (word "Exported movie to " path)
end


to setup
  clear-all

  set max-shade-dist 32      ;; distance over which trees can influence each other at most (see build-shells and get light-env)
  set abundances [0 0 0 0 0 0 0]
  set dbh-by-species [0 0 0 0 0 0 0]
  set age-by-species [0 0 0 0 0 0 0]
  set hgt-by-species [0 0 0 0 0 0 0]
  set mean-age-by-species [0 0 0 0 0 0 0]
  set mean-hgt-by-species [0 0 0 0 0 0 0]
  set BA-by-species [0 0 0 0 0 0 0]



  set spp-list but-first n-values (n-species + 1) [?]


  set patch-grain 4

  set niche-breadth 0.3

  set wgt-list []
  get-dnorm-lookup

  set colour-list []
  set max-hgt []
  set max-dbh []
  set max-age []
  set growth-form []
  set g-jabowa []
  set b2-jabowa []
  set b3-jabowa []

  set regen-height []

  set shade-tolerance []

  set repro-age []
  set seed-prod []
  set ldd-dispersal-dist []
  set ldd-dispersal-frac []
  set gap-maker []
  set supp-tolerance []
  set supp-mortality []
  set herbivory []
  set edge-response []


  set start-dbh []
  set start-dbh-sd []
  set start-abund []

  set seedlings-init []
  set saplings-init []


  set seedling-survival []
  set sapling-survival []
  set seedling-transition []
  set external-species []

  set saplings-to-plant (list 1 0 1 0 0 1 0)


  set a-tf-hgt 0.05289
  set b-tf-hgt -0.05695

  set demography-files []
  build-species-demography

 ;;seedlings-saplings

  ask patches
  [
    ;set seedlings n-values n-species [10]
    ;set saplings n-values n-species [2]

    set seedlings map [ifelse-value (? = 1) [10] [6] ] growth-form
    set saplings map [ifelse-value (? = 1) [2] [1] ] growth-form
  ]

  set seedling-mortality (map [1 - ?1 - ?2] seedling-survival seedling-transition)
  set sapling-mortality (map [1 - ?] sapling-survival)


  ;;
  set edge-b0 0
  set edge-b1 1



  ask patches
  [
      init-patch
      new-trees
  ]

  ask patches
    [set nhb-height get-nhb-height]

  if turtle-trees? = false
    [ ask patches [colour-patch]  ]

  ;; set tick 1
  set worldSize world-width * world-height
  update-abundances

  reset-ticks

end



to profile
      setup                  ;; set up the model
      profiler:start         ;; start profiling
      repeat 20 [ go ]       ;; run something you want to measure
      profiler:stop          ;; stop profiling
      print profiler:report  ;; view the results
      profiler:reset         ;; clear the data
end



to go

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
      if age > ra [disperse species dbh]
    ]

    ;; Dispersal:: external to the landscape
    if external-rain? [external-ldd]

    ;; Herbivory
    if herbivory? [ herbivore-effect ]

    ;; Macro-litterfall effect
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
to init-patch


  build-sets     ;; build annuli patch-sets for shading computation

  ;; set age int random-exponential 50
  set species ( random n-species ) + 1

  ;; set dbh random-float (item (species - 1) max-dbh ) * 0.5 ;; 0.01
  ifelse (item (species - 1) growth-form = 1)
  [
    set dbh min (list random-lognormal (item (species - 1) start-dbh) (item (species - 1) start-dbh-sd) (item (species - 1) max-dbh * 0.95))
    if dbh < 0.01 [set dbh 0.01]
    set height 1.37  + ((item (species - 1) b2-jabowa) * dbh) - ((item (species - 1) b3-jabowa) * dbh * dbh)
    set age get-age-from-dbh
  ]


  [
    set height min (list random-normal (item (species - 1) start-dbh) (item (species - 1) start-dbh-sd) (item (species - 1) max-hgt * 0.95))
    if height < 0 [set height 1.5]
    set dbh 0.1
    set age get-age-from-hgt
  ]

  set previous-growth []

  ;show dbh show height

  set expand? false
  set nhbs count item 0 nhb-set
  let d max ldd-dispersal-dist



  set edge-weight edge-effect get-edge-distance


end

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

;; Get apprx age of a tree of known DBH
to-report get-age-from-dbh

  let g item (species - 1) g-jabowa
  let maxdbh item (species - 1) max-dbh
  let maxheight item (species - 1) max-hgt
  let b2 item (species - 1) b2-jabowa
  let b3 item (species - 1) b3-jabowa


  let a 0
  let est-dbh 0.01 + random-float 0.01
  let l-height height


  while [est-dbh <= dbh]
  [
    let dbh-increment ( est-dbh * g * ( 1 - ( est-dbh * l-height ) / (maxdbh * maxheight) ) ) / ( 2.74 + 3 * b2 * est-dbh - 4 * b3 * est-dbh ^ 2 )
    set l-height 1.37  + (b2 * dbh) - (b3 * dbh * dbh)

    set est-dbh est-dbh + (dbh-increment)
    set a a + random-normal 0.8 0.1
  ]

  report round a + 1
end

;; Get apprx age of a tree of known hgt (this is for growth-form 2:: monocots)
to-report get-age-from-hgt


  let est-age 0
  let est-hgt 0.0 + random-float 0.01

  while [est-hgt <= height]
  [
    let hgt-increment a-tf-hgt * exp(b-tf-hgt * est-hgt)

    set est-hgt est-hgt + (hgt-increment)
    set est-age est-age + random-normal 0.8 0.1
  ]

  report round est-age + 1
end

;; Get apprx age of a tree of known hgt (this is for growth-form 2:: monocots)
to-report get-age-from-hgt-test [ch]

  let est-age 0
  let est-hgt 0.0 + random-float 0.01

  while [est-hgt <= ch]
  [
    let hgt-increment a-tf-hgt * exp(b-tf-hgt * est-hgt)

    set est-hgt est-hgt + (hgt-increment)
    set est-age est-age + random-normal 0.8 0.1
  ]

  report round est-age + 1

end

;; 'capture' each gap on the basis of the regen bank and shade tolerance


to capture-gap

  if sum saplings >= 1 and random-float 1 < (1 - (0.25 ^ (sum saplings))) ;; 0.25 is the prob of one sap being able to be an adult
  [
  ;; get for each species the idx (l-idx) in the light weights list for the patch
  let light-pos map [abs (nhb-light - ?1)] shade-tolerance
  let l-idx map [(?1 * 100) ] light-pos

  ;; this is a list of the actual weights
  let weights map [item (floor ?1) wgt-list] l-idx

  ;; now wgt the regenbank by the weights
  let regenbank-wgt  (map [?1 * ?2] saplings weights)

  ;;if sum saplings > 0
  ;;[
    let new-species (lottery regenbank-wgt) + 1        ;; +1 for zero-indexing

    set species new-species

    set last-change-tick ticks
    set n-change n-change + 1


    ifelse item (species - 1) growth-form = 1
    [
    ;; size of new recruits
      set dbh 0.01 + random-float 0.01     ;; dbh (in m) of 0.01 m (1 cm) + noise (0, 0.01)
      set height 1.37 + (item (species - 1) b2-jabowa) * dbh - (item (species - 1) b2-jabowa) * dbh ^ 2   ;; hgt from dbh
      set age 1
    ]
    [
      set height 1.5 + random-float 0.1
      set age 1
    ]

    ;; empty the regeneration bank
    set seedlings n-values n-species [0]
    set saplings n-values n-species [0]


    colour-patch
  ;;]
  ]
end

;; Simulate planting into the fragment
to restoration-planting

    ask patches
    [
      set saplings (map [?1 + ?2] saplings saplings-to-plant)
    ]

end







;; disperse 'seeds' from each cell
to disperse [disperser-spp diam]
  ;; This is from the perspective of a patch dispersing its seeds
  ;; Breaks this up into two components, each with their own routine:: immediate cells with immediate defined by crown width, long in the patch
  ;; The third component - external rain - is grid-level so-called in the go function

  nhb-dispersal disperser-spp diam  ;; this is into the immediate nhb as defined by crown width
  ldd-within-grid disperser-spp

end

;; Neighbourhood dispersal (component (a) in Morales thesis figure)
to nhb-dispersal [disperser-spp diam]
  ;; Local dispersal - distribute seedlings across the neighbourhood

  let n-seeds ( random-poisson item (disperser-spp - 1) seed-prod * ( 1 - (item (disperser-spp - 1) ldd-dispersal-frac)  ))

  let cw get-crown-width-from-dbh diam
  let shell-width ceiling (cw / patch-grain)
  if shell-width >= length nhb-set [set shell-width length nhb-set - 1]

  let dispersal-nhb no-patches

  ;; Build the nhb over which seeds locally dispersed = function of crown size and using the nhb-set list
  ifelse shell-width <= 1
    [ set dispersal-nhb (patch-set neighbors self) ]
    [ set dispersal-nhb sublist nhb-set 0 shell-width]


  ;; repeat rather than n-of as some patches may get more than one seed
  repeat n-seeds
  [
    ask one-of (patch-set dispersal-nhb)
    [

      if (item (disperser-spp - 1) seed-prod) > 0
      [

        let r-hgt item (disperser-spp - 1) regen-height

        ;; only establish if nhb hgt is less than the critical height (regen-height)
           if nhb-height <= r-hgt
           [
             let curr-r item (disperser-spp - 1) seedlings
             ;;let new-seedlings (random-poisson item (disperser-spp - 1) seed-prod)
             set seedlings replace-item (disperser-spp - 1) seedlings (curr-r + 1)
           ]
      ]
    ]
  ]
end

;; Longer distance dispersal but from within the grid (component (b) in Narkis' master piece)
to ldd-within-grid [disperser-spp]

  let n-ldd-seeds ( random-poisson (item (disperser-spp - 1) seed-prod) * (item (disperser-spp - 1) ldd-dispersal-frac) )

  repeat n-ldd-seeds
  [
      let D random-exponential ((item (disperser-spp - 1) ldd-dispersal-dist) / patch-grain)   ;; ldd-dispersal-distance is in m so this converts to patches
      let target patch-at-heading-and-distance random 360 D

      if target != nobody  ;; seeds that disperse beyond the patch are lost.
      [
        ask target
        [
          let r-hgt item (disperser-spp - 1) regen-height

           ;; only establish if nhb hgt is less than the critical height (regen-height)
           if nhb-height <= r-hgt
           [
             let curr-r item (disperser-spp - 1) seedlings
             set seedlings replace-item (disperser-spp - 1) seedlings (curr-r + 1)
           ]
        ]
      ]
  ]
end

;;  Long-distance dispersal from *beyond* the plot
;;  Compute total LDD seed rain and then disperse it across patches
to external-ldd


  ;; The code here is such that there is a chance for every species to invade from outside the plot, set here
  ;; to be equivalent to a on-grid abundance of 5% as a minimum
  let ldd-abundances abundances
  let crit-min 0.05 * count patches
  let idx 0

  set ldd-abundances map [ifelse-value (? < crit-min) [crit-min] [ ? ] ] ldd-abundances


  let ldd-to-disperse []

  set ldd-to-disperse (map [random-binomial ?1 ?2] ldd-abundances external-species)

  let spp 1
  foreach ldd-to-disperse
  [
     repeat ?
     [
       ask one-of patches
       [
         let curr-r item (spp - 1) seedlings
         set seedlings replace-item (spp - 1) seedlings (curr-r + 1)
       ]
     ]
    set spp spp + 1
  ]
end


;;; disperse 'seeds' from each cell
;;; N seeds (based on seed-prod) are dispersed a rnd direction D patches (where D drawn from exponential distribution)
;to disperse-OLD [disperser-spp]
;  ;; This is from the perspective of a patch dispersing its seeds
;
;  let N 0           ;; no. of seeds dispersed
;  let D 0           ;; distance seed dispersed
;
;  ;; Local dispersal - add a seedling to each of the neighbours
;  let n-nhb count neighbors
;
;  ;ask neighbors
;  ask (patch-set neighbors self)
;  [
;
;      if (item (disperser-spp - 1) seed-prod) > 0
;      [
;
;        let r-hgt item (disperser-spp - 1) regen-height
;
;        ;; only establish if nhb hgt is less than the critical height (regen-height)
;           if nhb-height <= r-hgt
;           [
;             let curr-r item (disperser-spp - 1) seedlings
;             let new-seedlings (random-poisson item (disperser-spp - 1) seed-prod)
;             set seedlings replace-item (disperser-spp - 1) seedlings (curr-r + ceiling new-seedlings)
;           ]
;      ]
;  ]
;
;  ; Long distance dispersal of the N seeds --- assumes all species have the same fraction of LDD??????
;  set N ( random-poisson item (disperser-spp - 1) seed-prod )
;
;  repeat N
;  [
;      set D random-exponential (item (disperser-spp - 1) dispersal)
;      let target patch-at-heading-and-distance random 360 random-exponential D
;
;      if target != nobody
;      [
;        ask target
;        [
;          let r-hgt item (disperser-spp - 1) regen-height
;
;           ;; only establish if nhb hgt is less than the critical height (regen-height)
;           if nhb-height <= r-hgt
;           [
;             let curr-r item (disperser-spp - 1) seedlings
;             set seedlings replace-item (disperser-spp - 1) seedlings (curr-r + 1)
;           ]
;        ]
;      ]
;  ]
;
;end

;; Reduce the seedling banks by the fraction that suffer herbivory
to herbivore-effect

  ask patches
  [
      set seedlings (map [round (?1 * ?2)] seedlings herbivory)
      if saplings-eaten? [ set saplings (map [round (?1 * ?2)] saplings herbivory )]
  ]

end

;; trigger a landscape-level disturbance event
to lsp-disturbance
  if random-float 1 < disturbFreq
  [
    start-disturbance

    ask patches with [disturbed? = true]
    [
     set species 0
     set height 0
     set disturbed? false
     set disturbedArea 0
     set pcolor 8

    ;; empty the regeneration bank
    set seedlings n-values n-species [0]
    set saplings n-values n-species [0]

    ]
  ]
end

to macrolitterfall
  if item (species - 1) growth-form = 2
  [
    set seedlings map [ifelse-value (? > 0) [? - 1] [0] ] seedlings
    let sap-die random n-species
    if item sap-die saplings > 0
    [
      set saplings replace-item sap-die saplings ((item sap-die saplings) - 1)
    ]
  ]
end

;to thin-regenbank
;
;  ;; use -ve exponential; t[half] = ln(2) / lambda -> lambda = ln(2) / t[half]
;  let lambda (ln 2) / sapHalfLife
;  set regenbank  (map [int (?1 + (- lambda * ?1))] regenbank)
;
;end
;


;; mortality - based on background mortality alone
to death

  if record-death? = true
  [
    file-open "track_mortality.txt"
  ]
  if record-prev? = true
  [
    file-open "tree_replacement.txt"
  ]


  let kill-me? false
  let mort-w 1

  ;; base mortality rate
  let ma item (species - 1) max-age
  let base-mort  (4 / ma)  ;;  from std gap models see shugart 1984 A Theory of Forest Dynamics... and also Liu & Ashton 1995 For Ecol Mgt 73, 157_75

  ;; if density-dependence in play
  ;; TO DO this needs careful thought
  if ddm = true
  [
     let f-species [species] of self
     let s-nhb count neighbors with [species = f-species]
     if s-nhb >= 4 [ set mort-w (1 + ( (s-nhb - 4 ) / 4 ) * 1) ]
     show mort-w
  ]

  ;; tree dies?
  ;; 1. baseline-mortality   ;; approximates the standard gap mortality model (see Keane et al. 2001)
  if random-float 1 < (base-mort * mort-w) [set kill-me? true
    if record-death? [file-write ticks  file-write species file-write age file-print " fate"]
  ]


  ;; 2. Suppression via low growth (p = growth-death if growth < crit-growth [a proportion]).
  ;; trees older than 10 years have a chance of competition based death
  ;; TO DO: needs close checking and tweaking - sensitive to crit-growth parameter

    let s-tol item (species - 1) supp-tolerance
    let s-mort item (species - 1) supp-mortality
    if age > 10 and (mean previous-growth < s-tol) and random-float 1 < s-mort [
      set kill-me? true
      if record-death? [file-write ticks file-write species file-write age file-print " supp"]
    ]


  if kill-me?
  [
    set prev-spp species
    set prev-height height

    set height 0                  ;; this is the assumed hgt of the new tree (not yet created)
    set species 0
    set previous-growth []
    if not turtle-trees? [set pcolor 8]

    ;; reset the regen bank?  otherwise get lock-in effects and quick drift to monodominance?
    ;;reset-regenbank


    if item (prev-spp - 1) gap-maker = 1 [ set expand? true ]   ;; flag as site to check for extension
  ]
;;write a file with the previous species and current species
if (record-prev?) and (ticks = recordprev-ticks) [file-write ticks file-write prev-spp  file-write  species file-print ""]

  ;;
end


;; grow the gap if the dying species is a 'gap maker'  -> a cone of neighbouring cells is affected
;; another option is to ranomdly hit nhbs until summed dbh of affected individuals greater than dbh of focal
to expand-gap

 let gap-center self
 let h (([height] of gap-center) / patch-grain) + 1      ;; rescale hgt to patch units and add one to ensure a nhb patch 'hit'

 let v nobody

 ask gap-center
 [
   sprout 1                    ;; need to make a turtle to access the in-cone primitive
   [
     ;; turtle has a rnd bearing in one of the cardinal dirn
     set heading one-of (but-first n-values (9) [?]) * 45
     set v patches in-cone h 0
     die
   ]
 ]

 if any? v
 [

   ask v
   [
     set height 0
     set species 0
;
;      ;; reset the regen bank?  otherwise get lock-in effects and quick drift to monodom?
      ;;reset-regenbank
   ]
   ;; if count v > 1 [ show count v ]
 ]

end

;; start landscape-level disturbance
to start-disturbance
  set disturbedArea 0

  ask one-of patches
  [
    set disturbed? true
    set disturbFront patch-set self               ;; a new disturb-front patch-set
  ]

  disturb-spread random-exponential (maxDisturbSize * worldSize)

end

;; spread the landscape-level disturbance - percolation algorithm
to disturb-spread [maxArea]
  while [ any? disturbFront and disturbedArea <= maxArea ]                 ;; Stop when we run out of active disturbance front
  [
    let newDisturbFront patch-set nobody     ;; Empty set of patches for the next 'round' of the disturbance

    ask disturbFront
    [
      let N neighbors with [ disturbed? != true ]

      ask N
      [
       if (random-float 1) <= 0.235 [ set newdisturbFront ( patch-set newdisturbFront self) ]
      ]
   ]

   set disturbFront newDisturbFront
   ask newDisturbFront [set disturbed? true]
   set disturbedArea disturbedArea + ( count newDisturbFront )
  ]


end

;;seedlings-saplings
to regenerate-patch-bank

  ;; juvenile mortality
  let dead-saplings (map [random-binomial ?1 ?2] saplings sapling-mortality)
  let dead-seedlings (map [random-binomial ?1 ?2] seedlings seedling-mortality)

  set saplings (map [?1 - ?2] saplings dead-saplings)

  set seedlings (map [?1 - ?2] seedlings dead-seedlings)

  ;; sapling regeneration
  let new-saplings (map [random-binomial ?1 ?2] seedlings seedling-transition)


  ;; saplings at t + 1 <- saplings * (1 - mort) + (seedlings * transition)
  set saplings (map [?1 + ?2] saplings new-saplings)

  ;; seedlings at t + 1 <- seedlings * (1 - mort - transition) + new-ones
  set seedlings (map [?1 - ?2] seedlings new-saplings)

end



;; AUXILLARY FUNCTIONS BELOW HERE...
to-report lottery [bankList]

  ;; -999 is a dummy number to report that a species was not returned (i.e., the bank was empty)
  let lotteryRepl -999

  if sum bankList > 0
  [
   let scaleBank (rescaleListToProbs bankList true)
   set lotteryRepl ( selectReplacement scaleBank)
  ]

  report lotteryRepl
end

to-report rescaleListToProbs [vec cumulative?]
  let scaledList [0 0 0 0]
  if (sum vec) > 0
    [ set scaledList map [? / sum(vec)] vec ]


  if cumulative? = true
    [set scaledList makeListCumulative scaledList]

  report scaledList
end

to-report makeListCumulative [vec]
  report butfirst reverse reduce [fput (?2 + first ?1) ?1] fput [0] vec
end

;; Select an item from a problist ascending and cumulative
;; returns index number to extract
to-report selectReplacement [probVec]

  let r random-float 1
  report position (first filter [r < ?] probVec) probVec

end

;; update a list containing the abundance (cell counts) of all species
to update-abundances
  let n [species] of patches
   set abundances (map [occurrences ?1 n] spp-list)
end

to update-species-dbh

     foreach spp-list
     [
       ifelse item (? - 1) abundances > 0
       [
         set dbh-by-species replace-item (? - 1) dbh-by-species (precision mean [dbh] of patches with [species = ?] 3 )
       ]
       [
         set dbh-by-species replace-item (? - 1) dbh-by-species 0
       ]
     ]
end


to update-species-age

     foreach spp-list
     [
       ifelse item (? - 1) abundances > 0
       [
         set age-by-species replace-item (? - 1) age-by-species (precision max [age] of patches with [species = ?] 0 )
       ]
       [
         set age-by-species replace-item (? - 1) age-by-species 0
       ]
     ]
end


to update-species-mean-age

     foreach spp-list
     [
       ifelse item (? - 1) abundances > 0
       [
         set mean-age-by-species replace-item (? - 1) mean-age-by-species (precision mean [age] of patches with [species = ?] 3 )
       ]
       [
         set mean-age-by-species replace-item (? - 1) mean-age-by-species 0
       ]
     ]
end

to update-species-hgt

     foreach spp-list
     [
       ifelse item (? - 1) abundances > 0
       [
         set hgt-by-species replace-item (? - 1) hgt-by-species (precision max [height] of patches with [species = ?] 3 )
       ]
       [
         set hgt-by-species replace-item (? - 1) hgt-by-species 0
       ]
     ]
end

to update-species-mean-hgt

     foreach spp-list
     [
       ifelse item (? - 1) abundances > 0
       [
         set mean-hgt-by-species replace-item (? - 1) mean-hgt-by-species (precision mean [height] of patches with [species = ?] 3 )
       ]
       [
         set mean-hgt-by-species replace-item (? - 1) mean-hgt-by-species 0
       ]
     ]
end



to update-species-BA



  ;;  report sum [(dbh / 2) ^ 2 * pi] of patches with [species != 0] / (count patches / (10000 / patch-grain ^ 2) )

  foreach spp-list
  [
  ifelse item (? - 1) abundances > 0
      [
      set BA-by-species replace-item (? - 1) BA-by-species ( precision ( (sum [(dbh / 2) ^ 2 * pi] of patches with [species = ?]) / (count patches / (10000 / patch-grain ^ 2))) 3)
    ]
     [
     set BA-by-species replace-item (? - 1) BA-by-species 0
       ]
     ]
end


;; Thanks, Seth!
to-report occurrences [x the-list]
  report reduce
    [ifelse-value (?2 = x) [?1 + 1] [?1]] (fput 0 the-list)
end

;; This is distance-weighted such that cells in-radius 1 are all counted, cells in-radius 1-2 are counted if hgt > 15
;; and in radius 2-3 if hgt > 30
to-report get-nhb-height

  let focal-height height    ;; height of patch requesting updated nhb height
  let idx 0
  ; let n 0
  ;let sum-hgt 0
  let crit-height (list 0 4 8 12 16 20 24 28 32)

  let shading-heights []

  ;; this loops over the annuli moving outwards (nhb-set is a list of patch-sets)
  foreach nhb-set
  [
    let shade-trees ? with [height > (item idx crit-height) and height >= focal-height]

     ;let d-set ? with [height > (item idx crit-height) and height >= focal-height]

     set shading-heights sentence shading-heights ([height] of shade-trees)


     ;set n n + count d-set
     ;set sum-hgt sum-hgt + sum [height] of d-set
     set idx idx + 1
  ]
  ; ifelse n > 0
  ifelse length shading-heights > 0
  ;
    [ report mean shading-heights ] ;
   ;[ report sum-hgt / n ]
    [ report 0 ]
end



;; Grow each tree following basic equations of Botkin et al. (1972) JABOWA
;; down-weight based on relative hgt of cell (following Dislich et al. 2009)
to grow
  let dbh-increment 0
  let hgt-increment 0
  let b2 0
  let b3 0
  let competitive-penalty 1
  set age age + 1

  ;; get the optimal growth rate (DBH increment) for the species:: same as Jabowa
  ifelse item (species - 1) growth-form = 1
  [
    let g item (species - 1) g-jabowa
    let maxdbh item (species - 1) max-dbh
    let maxheight item (species - 1) max-hgt
    set b2 item (species - 1) b2-jabowa
    set b3 item (species - 1) b3-jabowa

    set dbh-increment ( dbh * g * ( 1 - ( dbh * height ) / (maxdbh * maxheight) ) ) / ( 2.74 + 3 * b2 * dbh - 4 * b3 * dbh ^ 2 )
  ]
  [
    set hgt-increment a-tf-hgt * exp(height * b-tf-hgt)
  ]


  ;; and correct for nhb effects
  ifelse nhb-height <= height
   [ set competitive-penalty 1 ]
   [ set competitive-penalty min list (1.0) (comp-multiplier * ( (height / nhb-height ) ^ 0.5)) ]  ;; low value for comp penalty = more reduced growth (1 = optimal growth)


  ;; and edge effects if in play
  let edge-penalty 1
  ifelse edge-effects? ;; and edge? = true
    [ set edge-penalty (1 - (edge-weight * (1 - item (species - 1) edge-response))) ]   ;; 1 - X(1-y) where X is edge-weight and y is edge-response
    [ set edge-penalty 1 ]


  ;; store growth penalty history for suppression mortality
  let growth-reduction competitive-penalty * edge-penalty
  ifelse age < 5 or length previous-growth < 5
   [ set previous-growth fput growth-reduction previous-growth ]
   [ set previous-growth sublist (fput growth-reduction previous-growth) 0 5 ]           ;;;; Stores most recent 5 year's growth history


  ifelse item (species - 1) growth-form = 1
  [
    set dbh dbh + (dbh-increment * competitive-penalty * edge-penalty)
    set height 1.37  + (b2 * dbh) - (b3 * dbh * dbh)   ;; this is the original JABOWA height model equation
  ]
  [
    set height height + (hgt-increment * competitive-penalty * edge-penalty)
  ]

end

;; Reporter:: local light (shade) environment (see Dislich et al.) from 0 (high) to 1 (low)
;; TO DO - may needs some thought
to-report get-light-env [c-hgt]
  let l nhb-height / c-hgt     ;; col-hgt is the hrt in Dislich et al. - here assumed to be max max-hgt across all spp
  if l > 1 [set l 1]

  report l
end

;;; Builds a lookup list of the normal density for x from 0 to 1.0 by step grain
;;; Used to compute the light env growth index much more quickly...
to get-dnorm-lookup
  let d 0
  let grain 0.01
  let critical-d 1.0

  while [d <= critical-d] [
    set wgt-list lput (d-gaussian d 0 niche-breadth ) wgt-list
    set d d + grain
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


;; This build the species demography -?> may ultimately want to read from file
to build-species-demography
   ;; order of species: tawa, pigeon, pukatea, kawakawa, mahoe, rimu, tree-fern


   read-params-list-from-file demography-file

   read-params-list-from-file site-file

;; species are characterised by colour, maxhgt, maxdbh, maxage, G, shade-tolerance, baseseedprod, dispersal distance (mean from exp), gap-maker?
;  set colour-list (list 15 45 75 105 135 25)   ;; colour to display as (from netlogo colour table)
;  set max-hgt (list 35 15 35 6 12 35)         ;; max hgt in m
;  set max-dbh (list 1.2 0.5 1.2 0.3 0.6 2)              ;; max DBH in m
;  set max-age (list 450 100 450 60 60 800)    ;; max age in yrs
;  set g-jabowa (list 0.68 1.37 0.68 1.03 1.9 0.38)           ;; G from Botkin et al. 1972 these are rescaled from JABOWA to scale growth to m
;  set shade-tolerance (list 0.25 0.4 0.25 0.4 0.55 0.35)     ;; shade-tolerance for 0 (not) to 1 (very):: relative position  in light gradient (ave of 0.33)
;  set repro-age (list 20 10 20 10 10 20)           ;; minimum age for seed set
;  set seed-prod (list 1 1 1 2 1 1 )                ;; *relative* seed production
;  set dispersal (list 2 2 2 2 2 2)                ;; mean dispersal distance for Exponential distribution (units of patches)
;  set gap-maker(list 1 0 1 0 0 1)                 ;; make a gap on dying? (0 = no, 1 = yes)
;  set regen-height (list 35 35 35 35 35 35)         ;; max nhb hgt under which spp will recruit -- this can enhance shade intolerance?
;  set supp-tolerance (list 0.35 0.5 0.35 0.8 0.5 0.40)      ;; level of suppresison below which mortality risk increases
;  set supp-mortality (list 0.025 0.1 0.025 0.1 0.1 0.05)         ;; annual mortality rate for suppressed trees (ie five year mean > supp-tolerance)
;  set herbivory (list 0.3 0.5 0.3 0.5 0.9 0.3)              ;; proportion of seeds lost to herbivory
;  set edge-response (list 0.1 0.5 0.1 0.3 1 0.1)          ;; growth modifier at edge
;  ;;set seedling-survival (list 0.4 0.6 0.4 0.6 0.6 0.4)
;  set seedling-survival (list 0.5 0.6 0.5 0.6 0.6 0.5)
;  ;;set sapling-survival (list 0.4 0.85 0.4 0.7 0.8 0.7)
;  set sapling-survival (list 0.7 0.85 0.7 0.7 0.8 0.7)
;  set seedling-transition (list 0.04 0.07 0.04 0.1 0.07 0.03)
;  ;set start-dbh (list 0.369 0.11 0.227 0.01 0.284 0.01)              ;; Te miro data
;  ;set start-dbh-sd (list 0.1 0.01 0.2 0.01 0.1 0.01)                 ;; Te miro data
;  set start-dbh (list 0.338 0.133 0.402 0.085 0.22 0.01)              ;; Fenced hewitt
;  set start-dbh-sd (list 0.1 0.01 0.01 0.01 0.09 0.01)                ;;Fenced hewitt
;  ;set start-dbh (list 0.557 0.247 0.183 0.01 0.136 0.01)              ;; Unfenced Saywell
;  ;set start-dbh-sd (list 0.3 0.02 0.03 0.01 0.01 0.01)                ;; Unfenced Saywell

 get-jabowa-coeffs
end

;; calculate b2 and b2 (JABOWA growth coefficients; see Botkin 2001)
to get-jabowa-coeffs
    set b2-jabowa (map [(2 * (?1 - 1.37)) / ?2] max-hgt max-dbh)
    set b3-jabowa (map [((?1 - 1.37) / ?2 ^ 2)] max-hgt max-dbh)
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

;; Calculate the edge effect (0,1) at distance from edge
to-report edge-effect [d]
  report edge-b1 * exp(- edge-b2 * d) + edge-b0
end


;; Get distance from any cell to the edge
to-report get-edge-distance
   let x-distance min (list (pxcor - min-pxcor) (max-pxcor - pxcor))
   let y-distance min (list (pycor - min-pycor) (max-pxcor - pycor))

   report min (list x-distance y-distance)

end



to-report ba-per-ha
    report sum [(dbh / 2) ^ 2 * pi] of patches with [species != 0 and species != 7] / (count patches / (10000 / patch-grain ^ 2) )

end

to-report bank-tawa
report (sum [item 0 seedlings] of patches + sum [item 0 saplings] of patches) / 1000

end

to-report bank-pigeonwood
report (sum [item 1 seedlings] of patches + sum [item 1 saplings] of patches) / 1000

end

to-report bank-pukatea
report (sum [item 2 seedlings] of patches + sum [item 2 saplings] of patches) / 1000

end

to-report bank-kawakawa
report (sum [item 3 seedlings] of patches + sum [item 3 saplings] of patches) / 1000
end

to-report bank-mahoe
report (sum [item 4 seedlings] of patches + sum [item 4 saplings] of patches) / 1000
end

to-report bank-rimu
report (sum [item 5 seedlings] of patches + sum [item 5 saplings] of patches) / 1000
end

to-report get-crown-width-from-dbh [d]
  ;; this is a simplified allometric relationship from SORTIE-NZ
  set d d * 100                           ;; m to cm conversion
  report 0.284 * (d ^ 0.654)
end



to write-pattern
  carefully
  [
    file-open "pattern.txt"

    file-print "run x y species"

    ask patches
    [
      let X (word behaviorspace-run-number " " pxcor " " pycor " " species)
      file-print X
      ;;file-write behaviorspace-run-number file-write pxcor file-write pycor file-write species file-print ""
    ]
    file-close
  ]
  [
    show "File writing failed"
  ]
end

to update-biometry
  update-species-age
  update-species-dbh
  update-species-hgt
  update-species-mean-age
  update-species-mean-hgt
  update-species-BA
end

;; weighted/lottery/roulette selection
;; needs rnd extension
;; http://stackoverflow.com/questions/22615519/netlogo-weighted-random-draw-from-a-list-how-to-use-rnd-extension
to-report rnd-roulette [vals weights]
  let indices n-values length vals [ ? ]
  let index rnd:weighted-one-of indices [ item ? weights ]
  let state item index vals
  report state
end
@#$#@#$#@
GRAPHICS-WINDOW
320
10
1130
841
-1
-1
8.0
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
99
0
99
1
1
1
ticks
30.0

BUTTON
42
10
111
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
121
11
184
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
193
10
263
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
1133
13
1305
46
disturbFreq
disturbFreq
0
1
0.055
.005
1
NIL
HORIZONTAL

SLIDER
1133
51
1305
84
maxDisturbSize
maxDisturbSize
0
1
0.27
.01
1
NIL
HORIZONTAL

SWITCH
1308
15
1411
48
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
"pen-1" 1.0 0 -7500403 true "" "plot min [nhb-light] of patches"
"pen-2" 1.0 0 -7500403 true "" "plot max [nhb-light] of patches"

SWITCH
1309
51
1434
84
turtle-trees?
turtle-trees?
1
1
-1000

SLIDER
1134
108
1306
141
n-species
n-species
7
7
7
0
1
NIL
HORIZONTAL

SLIDER
1135
146
1307
179
max-ticks
max-ticks
1000
10000
800
250
1
NIL
HORIZONTAL

SLIDER
1133
193
1305
226
col-height
col-height
0
35
35
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
"set-histogram-num-bars 20\nset-plot-y-range 0 2000" "if plot? and ticks mod 10 = 0\n[ histogram [dbh] of patches with [species != 7] ]"
PENS
"default" 1.0 1 -16777216 true "" ""

PLOT
1136
620
1405
836
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
1169
643
1372
665
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
1313
151
1427
184
herbivory?
herbivory?
1
1
-1000

SWITCH
1315
186
1448
219
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
Tawa ---red\nPigeonwood-- yellow\nPukatea ---turquoise\nKawakawa ---blue\nMahoe ---pink\nRimu ---orange\nPonga ---dark green
11
0.0
1

SWITCH
317
845
459
878
saplings-eaten?
saplings-eaten?
1
1
-1000

SWITCH
656
845
827
878
restoration-planting?
restoration-planting?
1
1
-1000

SLIDER
471
844
643
877
planting-frequency
planting-frequency
1
10
5
1
1
NIL
HORIZONTAL

SLIDER
1142
286
1314
319
edge-b2
edge-b2
0
1
0
.01
1
NIL
HORIZONTAL

TEXTBOX
1136
329
1333
371
as edge-b2 increases distance over which edge-effect occurs reduces
11
0.0
1

PLOT
1161
456
1361
606
Edge Curve
Distance
E(d)
0.0
10.0
0.0
1.0
true
false
"let x n-values (max-pycor / 2) [?]\nforeach x\n[\n   plotxy ? edge-effect ?\n]" ""
PENS
"default" 1.0 0 -16777216 true "" ""

SWITCH
1006
844
1109
877
plot?
plot?
0
1
-1000

BUTTON
1124
845
1221
878
NIL
make-movie
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

INPUTBOX
25
767
276
827
demography-file
demography_newTF.txt
1
0
String

INPUTBOX
25
826
260
886
site-file
forest.txt
1
0
String

MONITOR
1136
232
1203
277
BA per ha
ba-per-ha
1
1
11

TEXTBOX
1456
96
1538
118
Dispersal from\noutside the world
9
15.0
1

SWITCH
1310
94
1443
127
external-rain?
external-rain?
0
1
-1000

MONITOR
1203
233
1283
278
Biggest tree
max [dbh] of patches
3
1
11

SWITCH
840
846
974
879
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
1283
234
1366
279
Mean tree size
mean [dbh] of patches
2
1
11

MONITOR
1369
233
1452
278
Median tree sizes
median [dbh] of patches
3
1
11

PLOT
14
206
271
388
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

SLIDER
1138
363
1310
396
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
1391
857
1563
890
recordprev-ticks
recordprev-ticks
0
2000
1000
100
1
NIL
HORIZONTAL

PLOT
1406
620
1657
836
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
1432
643
1582
661
500 randomly selected Tfs every 10 yr
8
0.0
1

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
NetLogo 5.3.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="baseline" repetitions="30" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <final>write-pattern</final>
    <timeLimit steps="2000"/>
    <metric>BA-by-species</metric>
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
