extends Node

# Osmanlı dönemi erkek isim havuzu (Türk, Rum, Ermeni, Yahudi, Slav, Arap kökenli)
# NOT: Artık her villager'ın kendi ismi var. Bu havuz yalnızca ismi boş gelen
# (eski kayıtlar / fallback) villager'lar için kullanılır.
const MALE_NAMES_OTTOMAN: Array[String] = [
	# Türk
	"Mehmet", "Ahmet", "Ali", "Hasan", "Hüseyin", "İbrahim", "Mustafa", "Osman",
	"Yusuf", "Süleyman", "Halil", "İsmail", "Ömer", "Abdullah", "Recep", "Ramazan",
	"Kemal", "Selim", "Murat", "Bayram", "Cemal", "Salih", "Nuri", "Şaban",
	"Hamza", "Bekir", "Veli", "Derviş", "Emin", "Fikret", "Gazi", "Tahir",
	# Rum (Yunan)
	"Dimitri", "Yannis", "Konstantin", "Nikolaos", "Andreas", "Georgios", "Petros",
	"Vasilis", "Christos", "Stavros", "Theodoros", "Lefteris", "Stefanos", "Spyros",
	# Ermeni
	"Garabed", "Hagop", "Krikor", "Sarkis", "Vartan", "Aram", "Arsen", "Bedros",
	"Dikran", "Gevorg", "Hrant", "Levon", "Nerses", "Tigran",
	# Yahudi
	"Avram", "Yakov", "Yosef", "David", "Shmuel", "Moshe", "Yitzhak",
	# Slav (Balkanlar)
	"Ivan", "Petar", "Stefan", "Nikola", "Marko", "Boris", "Vladimir", "Radovan",
	# Arap kökenli
	"Abdurrahman", "Abdülaziz", "Kazım", "Fahri", "Tevfik"
]

# Osmanlı dönemi kadın isim havuzu (Türk, Rum, Ermeni, Yahudi, Slav kökenli)
const FEMALE_NAMES_OTTOMAN: Array[String] = [
	# Türk
	"Ayşe", "Fatma", "Emine", "Hatice", "Zeynep", "Hanife", "Hürrem", "Mihri",
	"Gülbahar", "Safiye", "Nurbanu", "Leyla", "Nesrin", "Cemile", "Şahnaz",
	"Dilruba", "Gülizar", "Beyhan", "Servet", "Khadija",
	# Rum (Yunan)
	"Despina", "Eleni", "Maria", "Sofia", "Anna", "Katina", "Marika", "Katerina",
	"Theodora", "Eftalia", "Stamatia", "Vasiliki", "Marigo", "Foteini",
	# Ermeni
	"Takuhi", "Anahit", "Siranush", "Yester", "Mariam", "Verjin",
	# Yahudi
	"Sara", "Ester", "Rivka", "Rahel", "Roza",
	# Slav (Balkanlar)
	"Stana", "Vesna", "Draga", "Jelena", "Anica"
]

# Osmanlı dönemi kadın isim havuzu (Türk, Rum, Ermeni, Yahudi, Slav, Arap kökenli)
const FEMALE_NAMES_OTTOMAN: Array[String] = [
	# Türk isimleri
	"Fatma", "Ayşe", "Emine", "Hatice", "Zeynep", "Havva", "Elif", "Meryem",
	"Şerife", "Zehra", "Rukiye", "Hanife", "Naile", "Sabiha", "Nazlı", "Gülsüm",
	"Şükriye", "Hafize", "Şaziye", "Nuriye", "Cemile", "Feride", "Zübeyde", "Melek",
	"Hürmüz", "Dürdane", "Sultan", "Perihan", "Nazife", "Rabia", "Safiye", "Kamile",
	# Rum (Yunan) isimleri
	"Eleni", "Sofia", "Katerina", "Maria", "Anastasia", "Despina", "Vasiliki", "Irini",
	"Theodora", "Kalliopi", "Panagiota", "Chrysanthi", "Evanthia", "Angeliki", "Foteini", "Zoi",
	# Ermeni isimleri
	"Takuhi", "Zabel", "Arax", "Siranush", "Vartiter", "Aghavni", "Nvart", "Mariam",
	"Hripsime", "Anahit", "Zaruhi", "Satenik", "Knar", "Sirvart", "Yeva", "Armine",
	# Yahudi isimleri
	"Sara", "Rebeka", "Rahel", "Ester", "Miriam", "Hana", "Lea", "Yudit",
	"Devora", "Naomi", "Tamar", "Sion", "Bulisa", "Fortüne", "Gracia", "Reyna",
	# Slav isimleri (Balkanlar)
	"Milica", "Jelena", "Ana", "Ivana", "Vesna", "Danica", "Ljubica", "Radmila",
	"Snežana", "Biljana", "Draga", "Mirjana", "Slavica", "Stana", "Zorica", "Ruža",
	# Arap kökenli isimler
	"Aişe", "Halime", "Ümmühan", "Nazende", "Nesrin", "Amine", "Reyhan", "Selma"
]

var Saved_Villagers : Array = []
var Villager_Info_Pool : Array =[
	{
		"Info": {
			"Name": "Hasan",
			"Occupation": "Fisherman",
			"Mood": "Weary",
			"Gender": "Male",
			"Age": "44",
			"Health": "Scarred"
		},
		"History": [
			"Pulled three drowning boys from the strait during a winter squall",
			"Lost his father's boat when the moneylender seized it for debt"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Despina",
			"Occupation": "Net-mender",
			"Mood": "Content",
			"Gender": "Female",
			"Age": "38",
			"Health": "Healthy"
		},
		"History": [
			"Took in four dock orphans the winter their mother died",
			"Worked three nights without sleep to ready the nets before the great mackerel run"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Yannis",
			"Occupation": "Ferryman",
			"Mood": "Boastful",
			"Gender": "Male",
			"Age": "51",
			"Health": "Strong"
		},
		"History": [
			"Rowed a stranded pasha across the strait through a night storm",
			"Was the only one of four boys to swim ashore when his skiff capsized"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Ayşe",
			"Occupation": "Midwife",
			"Mood": "Gentle",
			"Gender": "Female",
			"Age": "56",
			"Health": "Aching joints"
		},
		"History": [
			"Refused to flee when fever swept the lower quarter",
			"Lost a mother and her child on the same night and never forgot it"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Krikor",
			"Occupation": "Coppersmith",
			"Mood": "Proud",
			"Gender": "Male",
			"Age": "47",
			"Health": "Burn-scarred"
		},
		"History": [
			"Burned his arms badly the night his workshop caught fire",
			"Engraved a tray that was sent to the capital as a wedding gift"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Stana",
			"Occupation": "Washerwoman",
			"Mood": "Bitter",
			"Gender": "Female",
			"Age": "33",
			"Health": "Frail"
		},
		"History": [
			"Was widowed young when her husband fell from the mill roof",
			"Watched the bey's steward seize her family's only field"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Mehmet",
			"Occupation": "Retired Janissary",
			"Mood": "Restless",
			"Gender": "Male",
			"Age": "60",
			"Health": "Limping"
		},
		"History": [
			"Came home from his third campaign with a shattered knee",
			"Carried a wounded comrade two days through the mountains to safety"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Eleni",
			"Occupation": "Vineyard-keeper",
			"Mood": "Cheerful",
			"Gender": "Female",
			"Age": "29",
			"Health": "Pregnant"
		},
		"History": [
			"Won the prize at the regional wine fair two years running",
			"Eloped with the man her father had forbidden her to marry"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Sarkis",
			"Occupation": "Calligrapher",
			"Mood": "Serene",
			"Gender": "Male",
			"Age": "68",
			"Health": "Failing eyesight"
		},
		"History": [
			"Copied a full Quran and a Gospel in the same year for two patrons",
			"Began losing his sight the winter he finished his largest manuscript"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Fatma",
			"Occupation": "Baker",
			"Mood": "Irritable",
			"Gender": "Female",
			"Age": "41",
			"Health": "Stout and hearty"
		},
		"History": [
			"Chased down and caught a bread thief with her peel in hand",
			"Kept the whole village fed from her oven through the famine winter"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Dimitri",
			"Occupation": "Carpenter",
			"Mood": "Stubborn",
			"Gender": "Male",
			"Age": "65",
			"Health": "Aching joints"
		},
		"History": [
			"Built the doors and shutters for half the houses in the village",
			"Carved the coffin for his own wife with his own hands"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Zeynep",
			"Occupation": "Carpet-weaver",
			"Mood": "Ambitious",
			"Gender": "Female",
			"Age": "24",
			"Health": "Healthy"
		},
		"History": [
			"Wove a pattern the valley had never seen and sold it to a city merchant",
			"Saved three years' wages toward a loom-house of her own"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Hagop",
			"Occupation": "Tanner",
			"Mood": "Resentful",
			"Gender": "Male",
			"Age": "39",
			"Health": "Weak chest"
		},
		"History": [
			"Lost the woman he meant to marry when her family balked at his trade",
			"Fell so deep into debt to the grocer that he signed over his hides"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Maria",
			"Occupation": "Herbalist",
			"Mood": "Curious",
			"Gender": "Female",
			"Age": "50",
			"Health": "Healthy"
		},
		"History": [
			"Broke a fever that had already killed two children before it reached the third",
			"Was accused of witchcraft by the new imam and cleared by the elders"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "İbrahim",
			"Occupation": "Miller",
			"Mood": "Greedy",
			"Gender": "Male",
			"Age": "54",
			"Health": "Gout-ridden"
		},
		"History": [
			"Bought out the last rival mill and left three villages dependent on him",
			"Was hauled before the kadi for shorting grain but walked free"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Anahit",
			"Occupation": "Lacemaker",
			"Mood": "Lonely",
			"Gender": "Female",
			"Age": "71",
			"Health": "Half-deaf"
		},
		"History": [
			"Buried all four of her children, the last to the coughing sickness",
			"Made the lace veil worn by three generations of village brides"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Petar",
			"Occupation": "Shepherd",
			"Mood": "Playful",
			"Gender": "Male",
			"Age": "19",
			"Health": "Healthy"
		},
		"History": [
			"Lost the whole flock in a mountain fog and found every goat by dawn",
			"Carved his first kaval from a reed and taught himself to play in one summer"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Khadija",
			"Occupation": "Spice-seller",
			"Mood": "Smug",
			"Gender": "Female",
			"Age": "45",
			"Health": "Robust"
		},
		"History": [
			"Smuggled a sack of saffron past the toll and made a small fortune",
			"Ruined a rival merchant by spreading what she knew of his debts"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Boris",
			"Occupation": "Blacksmith",
			"Mood": "Suspicious",
			"Gender": "Male",
			"Age": "58",
			"Health": "Missing two fingers"
		},
		"History": [
			"Lost two fingers to his own hammer in a single careless blow",
			"Drove out the apprentice he swore had robbed his strongbox"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Sofia",
			"Occupation": "Innkeeper",
			"Mood": "Weary",
			"Gender": "Female",
			"Age": "48",
			"Health": "Limping"
		},
		"History": [
			"Took over the roadside inn alone after her husband vanished on the road",
			"Was beaten by soldiers the night they found a debtor in her cellar"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Selim",
			"Occupation": "Beekeeper",
			"Mood": "Content",
			"Gender": "Male",
			"Age": "36",
			"Health": "Healthy"
		},
		"History": [
			"Was stung half-blind one spring and stayed with the hives regardless",
			"Gave his whole season's honey to the village the year the crops failed"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Takuhi",
			"Occupation": "Wet-nurse",
			"Mood": "Tender",
			"Gender": "Female",
			"Age": "27",
			"Health": "Nursing a newborn"
		},
		"History": [
			"Nursed the late chief's son alongside her own child",
			"Lost her first baby to the winter cold and took in a foundling soon after"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Yusuf",
			"Occupation": "Charcoal-burner",
			"Mood": "Melancholic",
			"Gender": "Male",
			"Age": "43",
			"Health": "Coughing badly"
		},
		"History": [
			"Spent a whole winter alone at the mountain kilns and came down changed",
			"Took up the cough the year the kiln smoke filled his hut"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Katina",
			"Occupation": "Fishmonger",
			"Mood": "Boastful",
			"Gender": "Female",
			"Age": "35",
			"Health": "Healthy"
		},
		"History": [
			"Threw a cheating buyer's whole basket into the sea before the whole market",
			"Out-haggled a city merchant so badly he never came back"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Vartan",
			"Occupation": "Bonesetter",
			"Mood": "Proud",
			"Gender": "Male",
			"Age": "62",
			"Health": "Trembling hands"
		},
		"History": [
			"Set the leg that let a crippled wrestler return and win the regional belt",
			"Lost a patient to a botched setting the first time his hands betrayed him"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Hatice",
			"Occupation": "Soap-maker",
			"Mood": "Hopeful",
			"Gender": "Female",
			"Age": "22",
			"Health": "Healthy"
		},
		"History": [
			"Made a rose soap the bathhouse women came to fight over",
			"Was betrothed to a boy the spring before he left with a trade caravan"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Stefan",
			"Occupation": "Cooper",
			"Mood": "Irritable",
			"Gender": "Male",
			"Age": "49",
			"Health": "Hunched back"
		},
		"History": [
			"Bent his back lifting barrels as a boy and never stood straight again",
			"Made the casks that carried the village's wine to the coast market"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Mariam",
			"Occupation": "Schoolteacher",
			"Mood": "Devout",
			"Gender": "Female",
			"Age": "33",
			"Health": "Healthy"
		},
		"History": [
			"Taught the village girls their letters in secret for a decade",
			"Was nearly turned out by the elders for teaching girls, and stayed anyway"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Halil",
			"Occupation": "Falconer",
			"Mood": "Smug",
			"Gender": "Male",
			"Age": "40",
			"Health": "Scarred"
		},
		"History": [
			"His hawk took a hare clean in front of a visiting bey",
			"Was clawed across the face training a half-wild goshawk"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Rivka",
			"Occupation": "Seamstress",
			"Mood": "Anxious",
			"Gender": "Female",
			"Age": "53",
			"Health": "Failing eyesight"
		},
		"History": [
			"Sewed the burial shrouds for the whole village through the last fever",
			"Strained her eyes to near blindness finishing a wedding gown by lamplight"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Andreas",
			"Occupation": "Mason",
			"Mood": "Proud",
			"Gender": "Male",
			"Age": "45",
			"Health": "Strong"
		},
		"History": [
			"Laid the cornerstone of the new village fountain",
			"Pulled a fellow mason from a collapsed wall and carried him out"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Emine",
			"Occupation": "Goatherd",
			"Mood": "Defiant",
			"Gender": "Female",
			"Age": "17",
			"Health": "Healthy"
		},
		"History": [
			"Refused the marriage her father arranged and took to the high pastures",
			"Killed a wolf with a sling the night it came for the kids"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Avram",
			"Occupation": "Grocer",
			"Mood": "Greedy",
			"Gender": "Male",
			"Age": "57",
			"Health": "Stout and hearty"
		},
		"History": [
			"Called in the debts of half the village in one hard winter",
			"Was robbed once and hunted the thief through three towns to get it back"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Gülbahar",
			"Occupation": "Dyer",
			"Mood": "Cheerful",
			"Gender": "Female",
			"Age": "30",
			"Health": "Stained hands"
		},
		"History": [
			"Dyed the deepest indigo cloth the market had ever seen",
			"Stained her hands permanently blue the year she perfected the dye"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Nikola",
			"Occupation": "Woodcutter",
			"Mood": "Stubborn",
			"Gender": "Male",
			"Age": "28",
			"Health": "Strong"
		},
		"History": [
			"Felled the great oak the whole village swore could not be moved",
			"Came to blows with his brother over their dead father's axe"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Nesrin",
			"Occupation": "Coffeehouse-keeper",
			"Mood": "Mischievous",
			"Gender": "Female",
			"Age": "38",
			"Health": "Healthy"
		},
		"History": [
			"Exposed a man's gambling debts to his wife across a crowded room",
			"Inherited the coffeehouse when its old keeper died owing her wages"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Garabed",
			"Occupation": "Jeweller",
			"Mood": "Anxious",
			"Gender": "Male",
			"Age": "52",
			"Health": "Weak chest"
		},
		"History": [
			"Set the stone in the chief's daughter's wedding ring",
			"Was robbed in the night once and has slept in his shop ever since"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Vesna",
			"Occupation": "Rose-grower",
			"Mood": "Serene",
			"Gender": "Female",
			"Age": "44",
			"Health": "Healthy"
		},
		"History": [
			"Distilled an attar so fine a city perfumer rode out to buy it",
			"Replanted her whole rose field after a frost killed it in a single night"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Ali",
			"Occupation": "Village-watchman",
			"Mood": "Weary",
			"Gender": "Male",
			"Age": "50",
			"Health": "Aching joints"
		},
		"History": [
			"Caught the granary thief that no one else believed existed",
			"Stood the wall alone the night raiders were rumored and none came"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Marika",
			"Occupation": "Storyteller",
			"Mood": "Playful",
			"Gender": "Female",
			"Age": "26",
			"Health": "Healthy"
		},
		"History": [
			"Held the whole coffeehouse silent for an hour with a single tale",
			"Learned a thousand stories from a blind grandmother before she died"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Süleyman",
			"Occupation": "Olive-presser",
			"Mood": "Content",
			"Gender": "Male",
			"Age": "61",
			"Health": "Limping"
		},
		"History": [
			"Slipped beneath the press-stone and walked crooked ever after",
			"Pressed the oil for every grove on the southern slope one record harvest"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Anna",
			"Occupation": "Bathhouse-keeper",
			"Mood": "Smug",
			"Gender": "Female",
			"Age": "47",
			"Health": "Robust"
		},
		"History": [
			"Took over the hamam when its old keeper died and scrubbed it spotless again",
			"Kept a noblewoman's secret and was paid in gold to forget it"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Aram",
			"Occupation": "Knife-grinder",
			"Mood": "Restless",
			"Gender": "Male",
			"Age": "34",
			"Health": "Healthy"
		},
		"History": [
			"Left his home village after a bitter quarrel and never settled again",
			"Ground the blades for a whole wedding feast in a single afternoon"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Cemile",
			"Occupation": "Gardener",
			"Mood": "Gentle",
			"Gender": "Female",
			"Age": "59",
			"Health": "Aching joints"
		},
		"History": [
			"Planted the great cypress that now marks the old graveyard",
			"Nursed the shrine garden back to life the year the spring ran dry"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Moshe",
			"Occupation": "Scribe",
			"Mood": "Bitter",
			"Gender": "Male",
			"Age": "48",
			"Health": "Trembling hands"
		},
		"History": [
			"Was passed over for the town clerkship he believed he had earned",
			"Wrote the petition that won a widow back her seized house"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Şahnaz",
			"Occupation": "Carpet-weaver",
			"Mood": "Lovesick",
			"Gender": "Female",
			"Age": "20",
			"Health": "Healthy"
		},
		"History": [
			"Wove a soldier's name into a rug's border where no one could read it",
			"Watched the man she loved march off to the front"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Petros",
			"Occupation": "Boatwright",
			"Mood": "Proud",
			"Gender": "Male",
			"Age": "55",
			"Health": "Missing two fingers"
		},
		"History": [
			"Built the fastest little fishing skiff in the whole bay",
			"Lost two fingers to a saw and finished the hull anyway"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Servet",
			"Occupation": "Tax-clerk",
			"Mood": "Smug",
			"Gender": "Male",
			"Age": "41",
			"Health": "Stout and hearty"
		},
		"History": [
			"Recorded every household's debt to the last para during the autumn levy",
			"Was nearly thrown down a well by farmers the year the taxes rose"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Draga",
			"Occupation": "Washerwoman",
			"Mood": "Grieving",
			"Gender": "Female",
			"Age": "36",
			"Health": "Frail"
		},
		"History": [
			"Lost two children to the summer fever in a single week",
			"Washed the burial shrouds of her own children with her own hands"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Hüseyin",
			"Occupation": "Drummer",
			"Mood": "Cheerful",
			"Gender": "Male",
			"Age": "23",
			"Health": "Healthy"
		},
		"History": [
			"Drummed three days straight for a visiting pasha's feast",
			"Took up his late father's drum the morning after he was buried"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Katerina",
			"Occupation": "Fortune-teller",
			"Mood": "Mischievous",
			"Gender": "Female",
			"Age": "49",
			"Health": "Healthy"
		},
		"History": [
			"Foretold the flood the year the old bridge washed out",
			"Was run out of a neighboring village for a reading that came true too well"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Recep",
			"Occupation": "Gravedigger",
			"Mood": "Melancholic",
			"Gender": "Male",
			"Age": "53",
			"Health": "Strong"
		},
		"History": [
			"Buried nearly everyone the village's elders still remember",
			"Dug graves through the night the fever took eleven souls in one week"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Mihri",
			"Occupation": "Embroiderer",
			"Mood": "Hopeful",
			"Gender": "Female",
			"Age": "18",
			"Health": "Healthy"
		},
		"History": [
			"Passed her verses hand to hand among the village's young women",
			"Was forbidden a book of her own and kept writing in secret regardless"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Stavros",
			"Occupation": "Cobbler",
			"Mood": "Irritable",
			"Gender": "Male",
			"Age": "44",
			"Health": "Gout-ridden"
		},
		"History": [
			"Resoled the boots of three generations of the same families",
			"Was crippled by gout the winter he turned forty"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Hanife",
			"Occupation": "Felt-maker",
			"Mood": "Stubborn",
			"Gender": "Female",
			"Age": "62",
			"Health": "Hunched back"
		},
		"History": [
			"Outlived two husbands and worked through the mourning of both",
			"Refused to buy a loom and beat her felt by hand into old age"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Marko",
			"Occupation": "Caravan-guard",
			"Mood": "Suspicious",
			"Gender": "Male",
			"Age": "37",
			"Health": "Scarred"
		},
		"History": [
			"Drove off bandits on the mountain road on two separate runs",
			"Took a knife across the ribs guarding a merchant's strongbox"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Safiye",
			"Occupation": "Spice-seller",
			"Mood": "Greedy",
			"Gender": "Female",
			"Age": "43",
			"Health": "Healthy"
		},
		"History": [
			"Cornered the pepper trade the year the coast road was closed",
			"Ruined a rival by buying up his stock and letting it rot in the storehouse"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Yakov",
			"Occupation": "Tinker",
			"Mood": "Weary",
			"Gender": "Male",
			"Age": "66",
			"Health": "Failing eyesight"
		},
		"History": [
			"Patched the pots and pans of the whole valley for forty years",
			"Gave up the finest work the year his eyes began to fail"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Theodora",
			"Occupation": "Dairywoman",
			"Mood": "Content",
			"Gender": "Female",
			"Age": "31",
			"Health": "Robust"
		},
		"History": [
			"Carried on her mother's cheese-making the season after she passed",
			"Saved the herd from the murrain that struck the neighboring village"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Kemal",
			"Occupation": "Sailmaker",
			"Mood": "Proud",
			"Gender": "Male",
			"Age": "39",
			"Health": "Healthy"
		},
		"History": [
			"Cut the sail that won the harbor race two summers past",
			"Re-rigged a foundering boat at sea and brought its crew home alive"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Nurbanu",
			"Occupation": "Healer",
			"Mood": "Serene",
			"Gender": "Female",
			"Age": "57",
			"Health": "Healthy"
		},
		"History": [
			"Saved the chief's son from a fever the bonesetter had given up on",
			"Swore an oath to her dying teacher to keep the remedies secret"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Derviş",
			"Occupation": "Wandering dervish",
			"Mood": "Devout",
			"Gender": "Male",
			"Age": "48",
			"Health": "Frail"
		},
		"History": [
			"Came to the lodge years ago and never once left again",
			"Gave away the last of his food during a famine and fasted for weeks"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Jelena",
			"Occupation": "Poultry-keeper",
			"Mood": "Cheerful",
			"Gender": "Female",
			"Age": "28",
			"Health": "Pregnant"
		},
		"History": [
			"Won her market stall in a wager and never gave it back",
			"Drove off a fox with nothing but a broom and her flock of geese"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Ömer",
			"Occupation": "Brick-maker",
			"Mood": "Resentful",
			"Gender": "Male",
			"Age": "35",
			"Health": "Withered hand"
		},
		"History": [
			"Made the bricks that built the new mosque's outer wall",
			"Lost the use of one hand when a kiln burst beside him"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Verjin",
			"Occupation": "Embroiderer",
			"Mood": "Lonely",
			"Gender": "Female",
			"Age": "64",
			"Health": "Half-deaf"
		},
		"History": [
			"Embroidered the cloth that draped the old chief's bier",
			"Lost most of her hearing to a fever in her fortieth year"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Vladimir",
			"Occupation": "Fur-trapper",
			"Mood": "Restless",
			"Gender": "Male",
			"Age": "41",
			"Health": "Scarred"
		},
		"History": [
			"Was mauled by a bear in the high forest and lived to keep its claw",
			"Brought down the wolf that had taken the village's lambs all winter"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Leyla",
			"Occupation": "Wedding-singer",
			"Mood": "Playful",
			"Gender": "Female",
			"Age": "25",
			"Health": "Healthy"
		},
		"History": [
			"Turned down a rich marriage so she could keep singing",
			"Sang at the wedding of nearly every family in the district one busy year"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Bekir",
			"Occupation": "Rope-maker",
			"Mood": "Content",
			"Gender": "Male",
			"Age": "52",
			"Health": "Aching joints"
		},
		"History": [
			"Twisted the rope that still hauls the quarter's well bucket",
			"Wore the skin from his hands the year he filled a shipwright's whole order"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Roza",
			"Occupation": "Candlemaker",
			"Mood": "Anxious",
			"Gender": "Female",
			"Age": "39",
			"Health": "Weak chest"
		},
		"History": [
			"Lit the synagogue's lamps every evening for twenty years",
			"Was trapped in a cellar fire as a child and has feared the dark since"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Salih",
			"Occupation": "Potter",
			"Mood": "Curious",
			"Gender": "Male",
			"Age": "30",
			"Health": "Healthy"
		},
		"History": [
			"Found a glaze of green no other potter could match",
			"Dug a hoard of strange old shards from the clay pit and kept them all"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Eftalia",
			"Occupation": "Olive-picker",
			"Mood": "Weary",
			"Gender": "Female",
			"Age": "46",
			"Health": "Aching joints"
		},
		"History": [
			"Picked the same grove every harvest since she was a small girl",
			"Fell from an old olive tree and climbed straight back up the next morning"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Murat",
			"Occupation": "Horse-breaker",
			"Mood": "Boastful",
			"Gender": "Male",
			"Age": "27",
			"Health": "Scarred"
		},
		"History": [
			"Broke the bey's wild stallion after three other men had failed",
			"Was thrown and trampled once and still bears the hoof-mark on his ribs"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Stamatia",
			"Occupation": "Mourner",
			"Mood": "Grieving",
			"Gender": "Female",
			"Age": "55",
			"Health": "Frail"
		},
		"History": [
			"Wailed at every funeral in three villages for thirty years",
			"Buried her own husband and could not weep a single tear"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Hamza",
			"Occupation": "Gunsmith",
			"Mood": "Suspicious",
			"Gender": "Male",
			"Age": "44",
			"Health": "Healthy"
		},
		"History": [
			"Repaired the watchmen's muskets through the night before a feared raid",
			"Caught an apprentice stealing powder and never trusted another"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Gülizar",
			"Occupation": "Henna-woman",
			"Mood": "Mischievous",
			"Gender": "Female",
			"Age": "50",
			"Health": "Healthy"
		},
		"History": [
			"Painted the bridal henna for half the marriages in the district",
			"Broke off a match by telling the bride what she knew of the groom"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Christos",
			"Occupation": "Icon-painter",
			"Mood": "Devout",
			"Gender": "Male",
			"Age": "58",
			"Health": "Failing eyesight"
		},
		"History": [
			"Painted the icons that still hang in the hillside chapel",
			"Finished his largest icon the year his sight began to dim"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Beyhan",
			"Occupation": "Reed-cutter",
			"Mood": "Content",
			"Gender": "Female",
			"Age": "34",
			"Health": "Healthy"
		},
		"History": [
			"Cut the reeds that thatched half the roofs in the marsh quarter",
			"Pulled a drowning child from the marsh channels one spring"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "İsmail",
			"Occupation": "Coffee-roaster",
			"Mood": "Proud",
			"Gender": "Male",
			"Age": "47",
			"Health": "Healthy"
		},
		"History": [
			"Perfected a coffee blend that kept the coffeehouse always full",
			"Refused a rich man's gold for the secret of his roast"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Sara",
			"Occupation": "Money-lender",
			"Mood": "Greedy",
			"Gender": "Female",
			"Age": "60",
			"Health": "Stout and hearty"
		},
		"History": [
			"Took over her late husband's ledgers and ran them harder than he ever had",
			"Forgave a single debt in twenty years, for a widow left with nothing"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Bedros",
			"Occupation": "Stonecutter",
			"Mood": "Stubborn",
			"Gender": "Male",
			"Age": "38",
			"Health": "Strong"
		},
		"History": [
			"Carved the headstones for both the church and the mosque yards",
			"Refused a rich man's coin to cut a lie into a tombstone"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Marigo",
			"Occupation": "Goatherd",
			"Mood": "Playful",
			"Gender": "Female",
			"Age": "16",
			"Health": "Healthy"
		},
		"History": [
			"Became the youngest ever to take the high flock out alone",
			"Brought the whole herd home through a storm that scattered older herders' flocks"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Veli",
			"Occupation": "Saddler",
			"Mood": "Weary",
			"Gender": "Male",
			"Age": "56",
			"Health": "Trembling hands"
		},
		"History": [
			"Made the saddle a courier rode all the way to the capital",
			"Gave up the fine stitching the year his hands began to shake"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Ester",
			"Occupation": "Glassblower",
			"Mood": "Curious",
			"Gender": "Female",
			"Age": "29",
			"Health": "Burn-scarred"
		},
		"History": [
			"Blew the colored panes for the new bathhouse dome",
			"Was burned across the arms the night the furnace flared up"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Osman",
			"Occupation": "Tile-maker",
			"Mood": "Content",
			"Gender": "Male",
			"Age": "51",
			"Health": "Healthy"
		},
		"History": [
			"Learned the craft from a master in İznik before coming home",
			"Laid the blue tiles that ring the village fountain"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Siranush",
			"Occupation": "Weaver",
			"Mood": "Lovesick",
			"Gender": "Female",
			"Age": "21",
			"Health": "Healthy"
		},
		"History": [
			"Wove a secret pattern of two birds into her dowry rug",
			"Was promised to a man her family later refused"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Radovan",
			"Occupation": "Raftsman",
			"Mood": "Restless",
			"Gender": "Male",
			"Age": "33",
			"Health": "Strong"
		},
		"History": [
			"Lost a brother to the river rapids and kept running them regardless",
			"Floated a whole season's timber to the coast through a spring flood"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Cemal",
			"Occupation": "Barber",
			"Mood": "Mischievous",
			"Gender": "Male",
			"Age": "40",
			"Health": "Healthy"
		},
		"History": [
			"Pulled the kadi's bad tooth and dined out on the tale for a year",
			"Shaved the village elders for twenty years and outlived most of them"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Vasiliki",
			"Occupation": "Basket-weaver",
			"Mood": "Content",
			"Gender": "Female",
			"Age": "48",
			"Health": "Aching joints"
		},
		"History": [
			"Wove the baskets the whole market still carries its goods in",
			"Kept weaving by feel alone the year her eyes began to fail"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Abdurrahman",
			"Occupation": "Imam",
			"Mood": "Devout",
			"Gender": "Male",
			"Age": "63",
			"Health": "Limping"
		},
		"History": [
			"Came as a young hoca and led the village's prayers for forty years",
			"Ended a blood feud between two families that had lasted a generation"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Anica",
			"Occupation": "Pig-keeper",
			"Mood": "Defiant",
			"Gender": "Female",
			"Age": "37",
			"Health": "Robust"
		},
		"History": [
			"Faced down a tax-clerk who tried to count her pigs twice",
			"Kept the only swine herd through years of scorn from her neighbors"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Yosef",
			"Occupation": "Rabbi",
			"Mood": "Serene",
			"Gender": "Male",
			"Age": "59",
			"Health": "Frail"
		},
		"History": [
			"Rebuilt the congregation's records from memory after a fire took the shelf",
			"Settled a dispute that had split two families for a generation"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Dilruba",
			"Occupation": "Silk-spinner",
			"Mood": "Hopeful",
			"Gender": "Female",
			"Age": "23",
			"Health": "Healthy"
		},
		"History": [
			"Spun the finest silk thread the valley had ever seen",
			"Saved three years toward a dowry no father had yet demanded of her"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Lefteris",
			"Occupation": "Diver",
			"Mood": "Boastful",
			"Gender": "Male",
			"Age": "31",
			"Health": "Weak chest"
		},
		"History": [
			"Dove the deepest reef in the bay for sponges none else would reach",
			"Took the chest-pain that never left him after one too-deep dive"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Hürrem",
			"Occupation": "Yogurt-seller",
			"Mood": "Cheerful",
			"Gender": "Female",
			"Age": "42",
			"Health": "Robust"
		},
		"History": [
			"Carried her yogurt jars through every lane at first light for years",
			"Fed the orphans for free the winter the herds nearly starved"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Tahir",
			"Occupation": "Well-digger",
			"Mood": "Weary",
			"Gender": "Male",
			"Age": "49",
			"Health": "Limping"
		},
		"History": [
			"Dug the well that saved the upper quarter through the dry year",
			"Was buried to the waist in a cave-in and dragged out with a ruined leg"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Foteini",
			"Occupation": "Mushroom-gatherer",
			"Mood": "Curious",
			"Gender": "Female",
			"Age": "27",
			"Health": "Healthy"
		},
		"History": [
			"Cured a poisoning with the very mushroom thought to have caused it",
			"Vanished into the forest for three days and came back with baskets full"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Mustafa",
			"Occupation": "Bridge-keeper",
			"Mood": "Stubborn",
			"Gender": "Male",
			"Age": "67",
			"Health": "Half-deaf"
		},
		"History": [
			"Kept the toll bridge for forty stubborn years",
			"Lost most of his hearing to a fever the same year his wife died"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Yester",
			"Occupation": "Button-maker",
			"Mood": "Anxious",
			"Gender": "Female",
			"Age": "52",
			"Health": "Trembling hands"
		},
		"History": [
			"Carved the bone buttons the district's tailors all prized",
			"Lost her steady hand the winter she turned fifty"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Tevfik",
			"Occupation": "Night-crier",
			"Mood": "Restless",
			"Gender": "Male",
			"Age": "36",
			"Health": "Healthy"
		},
		"History": [
			"Smelled the smoke first the night the granary nearly burned to the ground",
			"Took up the night-crier's round the year his father lost his voice"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "Rahel",
			"Occupation": "Quilt-maker",
			"Mood": "Gentle",
			"Gender": "Female",
			"Age": "58",
			"Health": "Aching joints"
		},
		"History": [
			"Stuffed the winter quilts that kept the village's poor alive through a hard freeze",
			"Sewed the quilt that wrapped a foundling left at her door one winter"
		],
		"Latest_news": []
	}
]
var _original_pool: Array = []
var _pool_loaded_from_save: bool = false
signal LoadComplete

func _ready() -> void:
	randomize()
	# Ensure all villagers in pool have Latest_news field
	for villager in Villager_Info_Pool:
		if not villager.has("Latest_news"):
			villager["Latest_news"] = []
		elif typeof(villager["Latest_news"]) == TYPE_STRING:
			# Migrate string to array if needed
			villager["Latest_news"] = [villager["Latest_news"]] if villager["Latest_news"] != "" else []
			
	if _original_pool.is_empty():
		_original_pool = _deep_duplicate(Villager_Info_Pool)
	
	pass

func update_latest_news(news_string: String) -> void:
	# 1. Update Saved_Villagers
	for villager in Saved_Villagers:
		if not villager.has("Latest_news"):
			villager["Latest_news"] = []
		# Add new news to the front
		villager["Latest_news"].push_front(news_string)
		# Limit to last 15 news items
		if villager["Latest_news"].size() > 15:
			villager["Latest_news"] = villager["Latest_news"].slice(0, 15)
	
	# 2. Update Villager_Info_Pool (so new villagers know the news)
	for villager in Villager_Info_Pool:
		if not villager.has("Latest_news"):
			villager["Latest_news"] = []
		villager["Latest_news"].push_front(news_string)
		if villager["Latest_news"].size() > 15:
			villager["Latest_news"] = villager["Latest_news"].slice(0, 15)
		
	# 3. Update active Workers
	get_tree().call_group("Villagers", "update_news", news_string)
	
	# Save changes
	save_array_to_json(Saved_Villagers, "Saved_Villagers.json")

func get_villager_info():
	var ChosenInfo = Villager_Info_Pool.pick_random()
	Villager_Info_Pool.erase(ChosenInfo)
	
	# Ensure Latest_news field exists and is an array
	if not ChosenInfo.has("Latest_news"):
		ChosenInfo["Latest_news"] = []
	elif typeof(ChosenInfo["Latest_news"]) == TYPE_STRING:
		ChosenInfo["Latest_news"] = [ChosenInfo["Latest_news"]] if ChosenInfo["Latest_news"] != "" else []
	if not ChosenInfo.has("Chat_log"):
		ChosenInfo["Chat_log"] = []
	ChosenInfo.erase("History_summary")
	
	# Havuzdaki "Gender" alanı sadece placeholder (hepsi "Male" olarak tanımlı) — asıl cinsiyet
	# burada %50 ihtimalle rastgele belirlenir, böylece kadın köylü modeli (v3) de spawn olabilir.
	if ChosenInfo.has("Info"):
		var gender: String = "Female" if randi() % 2 == 0 else "Male"
		ChosenInfo["Info"]["Gender"] = gender
		var name_pool: Array[String] = FEMALE_NAMES_OTTOMAN if gender == "Female" else MALE_NAMES_OTTOMAN
		if name_pool.size() > 0:
			var random_name = name_pool[randi() % name_pool.size()]
			ChosenInfo["Info"]["Name"] = random_name
			print("[VillagerAIInitializer] %s villager için Osmanlı dönemi ismi seçildi: %s" % [gender, random_name])
	return ChosenInfo
	
func _villager_save_base_dir() -> String:
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("get_profile_data_directory"):
		return str(sm.get_profile_data_directory())
	return "user://otto-man-save/profile_1/"

func save_array_to_json(array: Array, file_name: String) -> void:
	# Ensure the save directory exists
	create_save_directory()

	# Construct the full path for the file
	var full_path = _villager_save_base_dir() + file_name

	var file = FileAccess.open(full_path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(array)
		file.store_string(json_string)
		file.close()
		print("Successfully saved data to: %s" % full_path)
	else:
		push_error("Failed to open file for writing: %s" % full_path)
func Load_existing_villagers():
	if _pool_loaded_from_save:
		_pool_loaded_from_save = false
		emit_signal("LoadComplete")
		return
	var existing_villagers = load_array_from_json("Saved_Villagers.json")
	if existing_villagers.is_empty():
		Saved_Villagers.clear()
		emit_signal("LoadComplete")
		return
	for npc_data in existing_villagers:
		# Migration: Ensure Latest_news exists and is array
		if not npc_data.has("Latest_news"):
			npc_data["Latest_news"] = []
		elif typeof(npc_data["Latest_news"]) == TYPE_STRING:
			npc_data["Latest_news"] = [npc_data["Latest_news"]] if npc_data["Latest_news"] != "" else []
		if not npc_data.has("Chat_log") or typeof(npc_data["Chat_log"]) != TYPE_ARRAY:
			npc_data["Chat_log"] = []
		npc_data.erase("History_summary")
		Villager_Info_Pool.erase(npc_data)
	Saved_Villagers = existing_villagers
	
func load_array_from_json(file_name: String) -> Array:
	# Construct the full path for the file
	var full_path = _villager_save_base_dir() + file_name

	# Check if the file exists before trying to open it
	if not FileAccess.file_exists(full_path):
		print("Save file does not exist: %s" % full_path)
		return [] # Return empty array if file doesn't exist

	var file = FileAccess.open(full_path, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		var result = JSON.parse_string(json_string)
		
		# Validation: Check if result is valid array
		if result == null:
			push_error("Failed to parse JSON from: %s" % full_path)
			return []
			
		if result is Array:
			# Validate array contents (basic check)
			var valid_count = 0
			for item in result:
				if item is Dictionary and item.has("Info"):
					valid_count += 1
				else:
					push_warning("Invalid item in loaded JSON (missing Info): %s" % item)
			
			print("Successfully loaded data from: %s. Valid entries: %d/%d" % [full_path, valid_count, result.size()])
			emit_signal("LoadComplete")
			return result
		else:
			push_error("Loaded JSON is not an array or is invalid: %s" % full_path)
	else:
		push_error("Failed to open file for reading: %s" % full_path)
	return []

func create_save_directory() -> void:
	var dir = DirAccess.open("user://")
	if dir:
		if not dir.dir_exists("otto-man-save"):
			var error = dir.make_dir("otto-man-save")
			if error != OK:
				push_error("Failed to create save directory: user://otto-man-save/")
			else:
				print("Created save directory: user://otto-man-save/")
		for p: int in range(1, 4):
			var rel: String = "otto-man-save/profile_%d" % p
			if not dir.dir_exists(rel):
				dir.make_dir(rel)
	else:
		push_error("Failed to open user:// directory.")

func get_saved_villagers_copy() -> Array:
	return _deep_duplicate(Saved_Villagers)

func get_villager_pool_copy() -> Array:
	return _deep_duplicate(Villager_Info_Pool)

func set_saved_villagers_from_save(data: Array, remove_from_pool: bool = true) -> void:
	Saved_Villagers.clear()
	for entry in data:
		if entry is Dictionary:
			Saved_Villagers.append(_deep_duplicate(entry))
	if remove_from_pool:
		_remove_saved_from_pool()
	_pool_loaded_from_save = true

func set_villager_pool_from_save(pool: Array) -> void:
	Villager_Info_Pool = []
	for entry in pool:
		if entry is Dictionary:
			Villager_Info_Pool.append(_deep_duplicate(entry))
	_pool_loaded_from_save = true

func reset_to_defaults() -> void:
	Saved_Villagers.clear()
	if _original_pool.is_empty():
		_original_pool = _deep_duplicate(Villager_Info_Pool)
	Villager_Info_Pool = _deep_duplicate(_original_pool)
	_pool_loaded_from_save = false
	save_array_to_json(Saved_Villagers, "Saved_Villagers.json")

func _remove_saved_from_pool() -> void:
	if Villager_Info_Pool.is_empty() or Saved_Villagers.is_empty():
		return
	var pool_serialized: Array = []
	for entry in Villager_Info_Pool:
		pool_serialized.append(JSON.stringify(entry))
	for saved in Saved_Villagers:
		var saved_str = JSON.stringify(saved)
		var idx = pool_serialized.find(saved_str)
		if idx != -1:
			pool_serialized.remove_at(idx)
			Villager_Info_Pool.remove_at(idx)

func _deep_duplicate(value):
	if value is Array:
		var arr: Array = []
		for item in value:
			arr.append(_deep_duplicate(item))
		return arr
	elif value is Dictionary:
		var dict: Dictionary = {}
		for key in value.keys():
			dict[key] = _deep_duplicate(value[key])
		return dict
	else:
		return value
