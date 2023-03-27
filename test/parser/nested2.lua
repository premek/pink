return {
  ink=[[
"Well, Poirot? Murder or suicide?"
    *   "Murder"
        "And who did it?"
        * *     "Detective-Inspector Japp!"
        * *     "Captain Hastings!"
        * *     "Myself!"
    *   "Suicide"
]],
  expected = {
    {"para", '"Well, Poirot? Murder or suicide?"'},
    {"option", 1, '"Murder"', "", ""},
    {"para", '"And who did it?"'},
    {"option", 2, '"Detective-Inspector Japp!"', "", ""},
    {"option", 2, '"Captain Hastings!"', "", ""},
    {"option", 2, '"Myself!"', "", ""},
    {"option", 1, '"Suicide"', "", ""}
  }
}
