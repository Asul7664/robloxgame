-- Native-model creatures and their destination-specific catch weights.
return {
    Fish={
        {["Id"]="floppa", ["Name"]="Floppa Carp", ["Zone"]="Cove", ["Rarity"]=1, ["Chance"]=12, ["MinKg"]=0.3, ["MaxKg"]=1.1, ["Price"]=20, ["Difficulty"]=0.07, ["XP"]=25, ["Pattern"]="lazy", ["HookWindow"]=3.1, ["Nick"]="BIG EARS, STEADY NERVES", ["UseModelPortrait"]=true},
        {["Id"]="chipichapa", ["Name"]="Chipi Chapa", ["Zone"]="Cove", ["Rarity"]=2, ["Chance"]=6, ["MinKg"]=0.55, ["MaxKg"]=2.2, ["Price"]=32, ["Difficulty"]=0.11, ["XP"]=32, ["Pattern"]="wobble", ["HookWindow"]=2.8, ["Nick"]="DANCES EVEN ON THE HOOK", ["UseModelPortrait"]=true},
        {["Id"]="bobrito", ["Name"]="Bobrito Bandito", ["Zone"]="Reef", ["Rarity"]=2, ["Chance"]=8, ["MinKg"]=0.9, ["MaxKg"]=4.8, ["Price"]=44, ["Difficulty"]=0.16, ["XP"]=37, ["Pattern"]="pulse", ["HookWindow"]=2.7, ["Nick"]="THE SOMBRERO WON'T FIT IN THE NET", ["UseModelPortrait"]=true},
        {["Id"]="trippitroppi", ["Name"]="Trippi Troppi", ["Zone"]="Reef", ["Rarity"]=3, ["Chance"]=4, ["MinKg"]=1.8, ["MaxKg"]=7.5, ["Price"]=66, ["Difficulty"]=0.23, ["XP"]=49, ["Pattern"]="spiral", ["HookWindow"]=2.4, ["Nick"]="PART CAT, PART SHRIMP, ALL CHAOS", ["UseModelPortrait"]=true},
        {["Id"]="bombombini", ["Name"]="Bombombini Gusini", ["Zone"]="Reef", ["Rarity"]=3, ["Chance"]=2.5, ["MinKg"]=4.5, ["MaxKg"]=19, ["Price"]=90, ["Difficulty"]=0.26, ["XP"]=61, ["Pattern"]="dart", ["HookWindow"]=2.25, ["MinRodQuality"]=2, ["Nick"]="THIS GOOSE IS MAKING A COMBAT TURN", ["UseModelPortrait"]=true},
        {["Id"]="lirili", ["Name"]="Lirili Larila", ["Zone"]="Moss", ["Rarity"]=4, ["Chance"]=2.2, ["MinKg"]=5.5, ["MaxKg"]=22, ["Price"]=135, ["Difficulty"]=0.31, ["XP"]=82, ["Pattern"]="pulse", ["HookWindow"]=2.15, ["MinRodQuality"]=2, ["Nick"]="A CACTUS ELEPHANT IN SLIPPERS", ["UseModelPortrait"]=true},
        {["Id"]="chimpanzini", ["Name"]="Chimpanzini Bananini", ["Zone"]="Bloom", ["Rarity"]=5, ["Chance"]=0.85, ["MinKg"]=7, ["MaxKg"]=26, ["Price"]=225, ["Difficulty"]=0.36, ["XP"]=120, ["Pattern"]="berserk", ["HookWindow"]=1.9, ["MinRodQuality"]=2, ["Nick"]="BANANA MAYHEM IN THE LAGOON", ["UseModelPortrait"]=true},
        {["Id"]="frigocamelo", ["Name"]="Frigo Camelo", ["Zone"]="Dunes", ["Rarity"]=5, ["Chance"]=0.7, ["MinKg"]=18, ["MaxKg"]=48, ["Price"]=290, ["Difficulty"]=0.39, ["XP"]=135, ["Pattern"]="boss", ["HookWindow"]=1.9, ["MinRodQuality"]=3, ["Nick"]="A FRIDGE ON CAMEL LEGS", ["UseModelPortrait"]=true},
        {["Id"]="lavacca", ["Name"]="La Vacca Saturno Saturnita", ["Zone"]="Storm", ["Rarity"]=6, ["Chance"]=0.1, ["MinKg"]=30, ["MaxKg"]=58, ["Price"]=440, ["Difficulty"]=0.5, ["XP"]=175, ["Pattern"]="boss", ["HookWindow"]=2, ["MinRodQuality"]=3, ["Night"]=true, ["Nick"]="A NOCTURNAL COW WITH SATURN'S RINGS", ["UseModelPortrait"]=true},
    },
    IslandWeights={
        Reef={bobrito=30,trippitroppi=18,bombombini=5},
        Moss={floppa=4,lirili=2.2},
        Dunes={bobrito=12,bombombini=6,lirili=6,frigocamelo=1.2},
        Bloom={chipichapa=12,trippitroppi=5,chimpanzini=2},
        Storm={bombombini=8,lavacca=0.1},
    },
}
