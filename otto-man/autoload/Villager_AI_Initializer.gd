extends Node

# Osmanlı dönemi erkek isim havuzu (Türk, Rum, Ermeni, Yahudi, Slav, Arap kökenli)
const MALE_NAMES_OTTOMAN: Array[String] = [
	# Türk isimleri (5 katına çıkarıldı - 160 isim)
	"Mehmet", "Ahmet", "Ali", "Hasan", "Hüseyin", "İbrahim", "Mustafa", "Osman",
	"Yusuf", "Süleyman", "Halil", "İsmail", "Ömer", "Abdullah", "Recep", "Ramazan",
	"Kemal", "Selim", "Murat", "Bayram", "Cemal", "Salih", "Nuri", "Şaban",
	"Hamza", "Bekir", "Veli", "Derviş", "Emin", "Fikret", "Gazi", "Hacı",
	"Mehmet", "Ahmet", "Ali", "Hasan", "Hüseyin", "İbrahim", "Mustafa", "Osman",
	"Yusuf", "Süleyman", "Halil", "İsmail", "Ömer", "Abdullah", "Recep", "Ramazan",
	"Kemal", "Selim", "Murat", "Bayram", "Cemal", "Salih", "Nuri", "Şaban",
	"Hamza", "Bekir", "Veli", "Derviş", "Emin", "Fikret", "Gazi", "Hacı",
	"Mehmet", "Ahmet", "Ali", "Hasan", "Hüseyin", "İbrahim", "Mustafa", "Osman",
	"Yusuf", "Süleyman", "Halil", "İsmail", "Ömer", "Abdullah", "Recep", "Ramazan",
	"Kemal", "Selim", "Murat", "Bayram", "Cemal", "Salih", "Nuri", "Şaban",
	"Hamza", "Bekir", "Veli", "Derviş", "Emin", "Fikret", "Gazi", "Hacı",
	"Mehmet", "Ahmet", "Ali", "Hasan", "Hüseyin", "İbrahim", "Mustafa", "Osman",
	"Yusuf", "Süleyman", "Halil", "İsmail", "Ömer", "Abdullah", "Recep", "Ramazan",
	"Kemal", "Selim", "Murat", "Bayram", "Cemal", "Salih", "Nuri", "Şaban",
	"Hamza", "Bekir", "Veli", "Derviş", "Emin", "Fikret", "Gazi", "Hacı",
	"Mehmet", "Ahmet", "Ali", "Hasan", "Hüseyin", "İbrahim", "Mustafa", "Osman",
	"Yusuf", "Süleyman", "Halil", "İsmail", "Ömer", "Abdullah", "Recep", "Ramazan",
	"Kemal", "Selim", "Murat", "Bayram", "Cemal", "Salih", "Nuri", "Şaban",
	"Hamza", "Bekir", "Veli", "Derviş", "Emin", "Fikret", "Gazi", "Hacı",
	# Rum (Yunan) isimleri
	"Dimitri", "Yannis", "Konstantin", "Nikolaos", "Andreas", "Georgios", "Ioannis", "Petros",
	"Vasilis", "Christos", "Stavros", "Panagiotis", "Theodoros", "Alexandros", "Michalis", "Spyros",
	# Ermeni isimleri
	"Garabed", "Hagop", "Krikor", "Sarkis", "Vartan", "Aram", "Arsen", "Bedros",
	"Dikran", "Gevorg", "Hrant", "Karekin", "Levon", "Nerses", "Raffi", "Tigran",
	# Yahudi isimleri
	"Avram", "Yakov", "Yosef", "David", "Shmuel", "Moshe", "Yitzhak", "Yaakov",
	"Reuven", "Shimon", "Levi", "Yehuda", "Dan", "Naftali", "Gad", "Asher",
	# Slav isimleri (Balkanlar)
	"Ivan", "Petar", "Stefan", "Nikola", "Marko", "Jovan", "Milan", "Dragan",
	"Branko", "Zoran", "Vladimir", "Boris", "Miroslav", "Radovan", "Slobodan", "Vuk",
	# Arap kökenli isimler
	"Abdurrahman", "Abdülaziz", "Abdülhamit", "Abdülmecit", "Emin", "Fahri", "Hamit", "Kazım"
]

var Saved_Villagers : Array = []
var Villager_Info_Pool : Array =[
	{
		"Info": {
			"Name": "",
			"Occupation": "Fisherman",
			"Mood": "Angry",
			"Gender": "Male",
			"Age": "44",
			"Health": "Scarred"
		},
		"History": [
			"Helped rebuild a village after the Plague",
			"Was imprisoned after being accused of murder",
			"Worked for a cruel captain before escaping"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Carpenter",
			"Mood": "Angry",
			"Gender": "Male",
			"Age": "65",
			"Health": "Burned"
		},
		"History": [
			"Was imprisoned after being accused of theft",
			"Survived the ambush at Raventon",
			"Helped rebuild a village after the Border Conflict"
		],
		"Latest_news": []
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Soldier",
			"Mood": "Content",
			"Gender": "Male",
			"Age": "29",
			"Health": "Burned"
		},
		"History": [
			"Survived the ambush at Raventon",
			"Watched a loved one die during the Border Conflict",
			"Helped rebuild a village after the Winter Siege"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Fisherman",
			"Mood": "Nervous",
			"Gender": "Male",
			"Age": "25",
			"Health": "Injured"
		},
		"History": [
			"Spent years training under a master in Red Hill",
			"Worked for a cruel captain before escaping",
			"Protected a child during the Plague"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Soldier",
			"Mood": "Angry",
			"Gender": "Male",
			"Age": "25",
			"Health": "Bruised"
		},
		"History": [
			"Watched a loved one die during the Border Conflict",
			"Worked for a cruel abbot before escaping",
			"Was imprisoned after being accused of treason"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Weaver",
			"Mood": "Haunted",
			"Gender": "Male",
			"Age": "44",
			"Health": "Bruised"
		},
		"History": [
			"Protected a child during the Border Conflict",
			"Worked for a cruel noblewoman before escaping",
			"Survived the ambush at The Northern Pass"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Stablehand",
			"Mood": "Resigned",
			"Gender": "Male",
			"Age": "56",
			"Health": "Injured"
		},
		"History": [
			"Fled from Stonewatch after fire",
			"Lost everything in the earthquake",
			"Stole food during the Fire of Greymoor and was punished"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Merchant",
			"Mood": "Resigned",
			"Gender": "Male",
			"Age": "22",
			"Health": "Limping"
		},
		"History": [
			"Lost everything in the earthquake",
			"Spent years training under a master in Greymoor",
			"Helped rebuild a village after the Border Conflict"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Hunter",
			"Mood": "Content",
			"Gender": "Male",
			"Age": "62",
			"Health": "Healthy"
		},
		"History": [
			"Spent years training under a master in Stonewatch",
			"Watched a loved one die during the Harvest Famine",
			"Worked for a cruel abbot before escaping"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Blacksmith",
			"Mood": "Paranoid",
			"Gender": "Male",
			"Age": "70",
			"Health": "Weak"
		},
		"History": [
			"Worked for a cruel captain before escaping",
			"Was imprisoned after being accused of treason",
			"Stole food during the Plague and was punished"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Teacher",
			"Mood": "Lonely",
			"Gender": "Male",
			"Age": "70",
			"Health": "Limping"
		},
		"History": [
			"Spent years training under a master in Greymoor",
			"Worked for a cruel captain before escaping",
			"Stole food during the Fire of Greymoor and was punished"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Teacher",
			"Mood": "Hopeful",
			"Gender": "Male",
			"Age": "59",
			"Health": "Burned"
		},
		"History": [
			"Helped rebuild a village after the Winter Siege",
			"Fled from Red Hill after flood",
			"Survived the ambush at Stonewatch"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Weaver",
			"Mood": "Haunted",
			"Gender": "Male",
			"Age": "61",
			"Health": "Scarred"
		},
		"History": [
			"Was imprisoned after being accused of espionage",
			"Worked for a cruel captain before escaping",
			"Protected a child during the Winter Siege"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Stablehand",
			"Mood": "Angry",
			"Gender": "Male",
			"Age": "51",
			"Health": "Burned"
		},
		"History": [
			"Protected a child during the Harvest Famine",
			"Spent years training under a master in Red Hill",
			"Lost everything in the earthquake"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Blacksmith",
			"Mood": "Lonely",
			"Gender": "Male",
			"Age": "19",
			"Health": "Scarred"
		},
		"History": [
			"Helped rebuild a village after the Winter Siege",
			"Stole food during the Border Conflict and was punished",
			"Lost everything in the earthquake"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Herbalist",
			"Mood": "Angry",
			"Gender": "Male",
			"Age": "61",
			"Health": "Healthy"
		},
		"History": [
			"Lost everything in the fire",
			"Worked for a cruel noblewoman before escaping",
			"Stole food during the Fire of Greymoor and was punished"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Stablehand",
			"Mood": "Calm",
			"Gender": "Male",
			"Age": "68",
			"Health": "Burned"
		},
		"History": [
			"Worked for a cruel captain before escaping",
			"Fled from Raventon after earthquake",
			"Watched a loved one die during the Border Conflict"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Herbalist",
			"Mood": "Nervous",
			"Gender": "Male",
			"Age": "29",
			"Health": "Healthy"
		},
		"History": [
			"Was imprisoned after being accused of murder",
			"Spent years training under a master in Raventon",
			"Lost everything in the fire"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Soldier",
			"Mood": "Nervous",
			"Gender": "Male",
			"Age": "49",
			"Health": "Bruised"
		},
		"History": [
			"Stole food during the Harvest Famine and was punished",
			"Was imprisoned after being accused of theft",
			"Survived the ambush at Greymoor"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Fisherman",
			"Mood": "Resigned",
			"Gender": "Male",
			"Age": "37",
			"Health": "Scarred"
		},
		"History": [
			"Spent years training under a master in Stonewatch",
			"Survived the ambush at Red Hill",
			"Watched a loved one die during the Fire of Greymoor"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Fisherman",
			"Mood": "Worried",
			"Gender": "Male",
			"Age": "42",
			"Health": "Limping"
		},
		"History": [
			"Watched a loved one die during the Winter Siege",
			"Worked for a cruel lord before escaping",
			"Stole food during the Winter Siege and was punished"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Weaver",
			"Mood": "Paranoid",
			"Gender": "Male",
			"Age": "48",
			"Health": "Healthy"
		},
		"History": [
			"Was imprisoned after being accused of murder",
			"Helped rebuild a village after the Harvest Famine",
			"Protected a child during the Border Conflict"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Hunter",
			"Mood": "Angry",
			"Gender": "Male",
			"Age": "69",
			"Health": "Healthy"
		},
		"History": [
			"Was imprisoned after being accused of murder",
			"Protected a child during the Plague",
			"Helped rebuild a village after the Fire of Greymoor"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Hunter",
			"Mood": "Angry",
			"Gender": "Male",
			"Age": "42",
			"Health": "Limping"
		},
		"History": [
			"Spent years training under a master in The Northern Pass",
			"Stole food during the Border Conflict and was punished",
			"Watched a loved one die during the Harvest Famine"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Herbalist",
			"Mood": "Content",
			"Gender": "Male",
			"Age": "63",
			"Health": "Bruised"
		},
		"History": [
			"Fled from The Northern Pass after bandit raid",
			"Watched a loved one die during the Plague",
			"Stole food during the Fire of Greymoor and was punished"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Herbalist",
			"Mood": "Worried",
			"Gender": "Male",
			"Age": "21",
			"Health": "Weak"
		},
		"History": [
			"Worked for a cruel lord before escaping",
			"Helped rebuild a village after the Border Conflict",
			"Spent years training under a master in Red Hill"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Herbalist",
			"Mood": "Angry",
			"Gender": "Male",
			"Age": "40",
			"Health": "Burned"
		},
		"History": [
			"Worked for a cruel abbot before escaping",
			"Lost everything in the flood",
			"Survived the ambush at Red Hill"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Teacher",
			"Mood": "Lonely",
			"Gender": "Male",
			"Age": "37",
			"Health": "Bruised"
		},
		"History": [
			"Worked for a cruel captain before escaping",
			"Was imprisoned after being accused of murder",
			"Survived the ambush at Stonewatch"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Hunter",
			"Mood": "Hopeful",
			"Gender": "Male",
			"Age": "63",
			"Health": "Weak"
		},
		"History": [
			"Fled from The Northern Pass after flood",
			"Protected a child during the Plague",
			"Watched a loved one die during the Plague"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Teacher",
			"Mood": "Paranoid",
			"Gender": "Male",
			"Age": "28",
			"Health": "Bruised"
		},
		"History": [
			"Helped rebuild a village after the Winter Siege",
			"Fled from The Northern Pass after earthquake",
			"Protected a child during the Winter Siege"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Hunter",
			"Mood": "Calm",
			"Gender": "Male",
			"Age": "61",
			"Health": "Injured"
		},
		"History": [
			"Was imprisoned after being accused of theft",
			"Stole food during the Plague and was punished",
			"Survived the ambush at The Northern Pass"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Blacksmith",
			"Mood": "Resigned",
			"Gender": "Male",
			"Age": "27",
			"Health": "Healthy"
		},
		"History": [
			"Lost everything in the flood",
			"Watched a loved one die during the Harvest Famine",
			"Protected a child during the Fire of Greymoor"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Carpenter",
			"Mood": "Hopeful",
			"Gender": "Male",
			"Age": "60",
			"Health": "Scarred"
		},
		"History": [
			"Was imprisoned after being accused of treason",
			"Lost everything in the bandit raid",
			"Survived the ambush at Raventon"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Stablehand",
			"Mood": "Resigned",
			"Gender": "Male",
			"Age": "25",
			"Health": "Healthy"
		},
		"History": [
			"Survived the ambush at The Northern Pass",
			"Was imprisoned after being accused of treason",
			"Helped rebuild a village after the Plague"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Blacksmith",
			"Mood": "Paranoid",
			"Gender": "Male",
			"Age": "46",
			"Health": "Limping"
		},
		"History": [
			"Was imprisoned after being accused of murder",
			"Watched a loved one die during the Fire of Greymoor",
			"Helped rebuild a village after the Plague"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Herbalist",
			"Mood": "Worried",
			"Gender": "Male",
			"Age": "52",
			"Health": "Weak"
		},
		"History": [
			"Survived the ambush at Stonewatch",
			"Watched a loved one die during the Winter Siege",
			"Was imprisoned after being accused of theft"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Stablehand",
			"Mood": "Worried",
			"Gender": "Male",
			"Age": "38",
			"Health": "Limping"
		},
		"History": [
			"Spent years training under a master in Stonewatch",
			"Stole food during the Border Conflict and was punished",
			"Survived the ambush at Stonewatch"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Carpenter",
			"Mood": "Haunted",
			"Gender": "Male",
			"Age": "37",
			"Health": "Burned"
		},
		"History": [
			"Protected a child during the Plague",
			"Spent years training under a master in Red Hill",
			"Fled from Red Hill after bandit raid"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Fisherman",
			"Mood": "Haunted",
			"Gender": "Male",
			"Age": "24",
			"Health": "Burned"
		},
		"History": [
			"Protected a child during the Border Conflict",
			"Was imprisoned after being accused of murder",
			"Watched a loved one die during the Plague"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Blacksmith",
			"Mood": "Paranoid",
			"Gender": "Male",
			"Age": "28",
			"Health": "Weak"
		},
		"History": [
			"Watched a loved one die during the Plague",
			"Protected a child during the Harvest Famine",
			"Lost everything in the earthquake"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Blacksmith",
			"Mood": "Lonely",
			"Gender": "Male",
			"Age": "30",
			"Health": "Healthy"
		},
		"History": [
			"Helped rebuild a village after the Fire of Greymoor",
			"Watched a loved one die during the Plague",
			"Fled from Red Hill after fire"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Carpenter",
			"Mood": "Nervous",
			"Gender": "Male",
			"Age": "61",
			"Health": "Bruised"
		},
		"History": [
			"Spent years training under a master in The Northern Pass",
			"Lost everything in the fire",
			"Helped rebuild a village after the Fire of Greymoor"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Herbalist",
			"Mood": "Haunted",
			"Gender": "Male",
			"Age": "66",
			"Health": "Limping"
		},
		"History": [
			"Protected a child during the Harvest Famine",
			"Watched a loved one die during the Harvest Famine",
			"Survived the ambush at Raventon"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Soldier",
			"Mood": "Worried",
			"Gender": "Male",
			"Age": "33",
			"Health": "Weak"
		},
		"History": [
			"Fled from Stonewatch after fire",
			"Survived the ambush at Greymoor",
			"Was imprisoned after being accused of treason"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Soldier",
			"Mood": "Lonely",
			"Gender": "Male",
			"Age": "47",
			"Health": "Weak"
		},
		"History": [
			"Helped rebuild a village after the Harvest Famine",
			"Survived the ambush at Red Hill",
			"Lost everything in the earthquake"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Fisherman",
			"Mood": "Calm",
			"Gender": "Male",
			"Age": "36",
			"Health": "Injured"
		},
		"History": [
			"Survived the ambush at The Northern Pass",
			"Watched a loved one die during the Border Conflict",
			"Worked for a cruel abbot before escaping"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Fisherman",
			"Mood": "Paranoid",
			"Gender": "Male",
			"Age": "37",
			"Health": "Injured"
		},
		"History": [
			"Was imprisoned after being accused of murder",
			"Watched a loved one die during the Winter Siege",
			"Protected a child during the Fire of Greymoor"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Carpenter",
			"Mood": "Paranoid",
			"Gender": "Male",
			"Age": "29",
			"Health": "Healthy"
		},
		"History": [
			"Worked for a cruel noblewoman before escaping",
			"Helped rebuild a village after the Winter Siege",
			"Watched a loved one die during the Fire of Greymoor"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Blacksmith",
			"Mood": "Haunted",
			"Gender": "Male",
			"Age": "66",
			"Health": "Healthy"
		},
		"History": [
			"Fled from Stonewatch after bandit raid",
			"Protected a child during the Harvest Famine",
			"Helped rebuild a village after the Winter Siege"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Fisherman",
			"Mood": "Paranoid",
			"Gender": "Male",
			"Age": "36",
			"Health": "Bruised"
		},
		"History": [
			"Protected a child during the Harvest Famine",
			"Spent years training under a master in Greymoor",
			"Worked for a cruel noblewoman before escaping"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Merchant",
			"Mood": "Angry",
			"Gender": "Male",
			"Age": "49",
			"Health": "Healthy"
		},
		"History": [
			"Was imprisoned after being accused of espionage",
			"Worked for a cruel noblewoman before escaping",
			"Lost everything in the earthquake"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Teacher",
			"Mood": "Angry",
			"Gender": "Male",
			"Age": "52",
			"Health": "Weak"
		},
		"History": [
			"Was imprisoned after being accused of treason",
			"Stole food during the Plague and was punished",
			"Watched a loved one die during the Harvest Famine"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Weaver",
			"Mood": "Nervous",
			"Gender": "Male",
			"Age": "40",
			"Health": "Healthy"
		},
		"History": [
			"Was imprisoned after being accused of theft",
			"Lost everything in the flood",
			"Worked for a cruel abbot before escaping"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Fisherman",
			"Mood": "Nervous",
			"Gender": "Male",
			"Age": "67",
			"Health": "Healthy"
		},
		"History": [
			"Was imprisoned after being accused of espionage",
			"Protected a child during the Harvest Famine",
			"Stole food during the Border Conflict and was punished"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Stablehand",
			"Mood": "Resigned",
			"Gender": "Male",
			"Age": "43",
			"Health": "Burned"
		},
		"History": [
			"Protected a child during the Fire of Greymoor",
			"Was imprisoned after being accused of espionage",
			"Survived the ambush at The Northern Pass"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Fisherman",
			"Mood": "Angry",
			"Gender": "Male",
			"Age": "66",
			"Health": "Healthy"
		},
		"History": [
			"Survived the ambush at The Northern Pass",
			"Lost everything in the earthquake",
			"Helped rebuild a village after the Plague"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Carpenter",
			"Mood": "Calm",
			"Gender": "Male",
			"Age": "29",
			"Health": "Scarred"
		},
		"History": [
			"Fled from The Northern Pass after earthquake",
			"Lost everything in the earthquake",
			"Watched a loved one die during the Winter Siege"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Fisherman",
			"Mood": "Paranoid",
			"Gender": "Male",
			"Age": "19",
			"Health": "Injured"
		},
		"History": [
			"Stole food during the Plague and was punished",
			"Lost everything in the earthquake",
			"Watched a loved one die during the Plague"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Stablehand",
			"Mood": "Worried",
			"Gender": "Male",
			"Age": "19",
			"Health": "Healthy"
		},
		"History": [
			"Survived the ambush at Red Hill",
			"Helped rebuild a village after the Plague",
			"Spent years training under a master in Red Hill"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Teacher",
			"Mood": "Haunted",
			"Gender": "Male",
			"Age": "22",
			"Health": "Limping"
		},
		"History": [
			"Fled from Greymoor after flood",
			"Was imprisoned after being accused of murder",
			"Lost everything in the bandit raid"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Blacksmith",
			"Mood": "Content",
			"Gender": "Male",
			"Age": "70",
			"Health": "Healthy"
		},
		"History": [
			"Fled from Stonewatch after flood",
			"Watched a loved one die during the Border Conflict",
			"Stole food during the Plague and was punished"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Weaver",
			"Mood": "Hopeful",
			"Gender": "Male",
			"Age": "32",
			"Health": "Healthy"
		},
		"History": [
			"Protected a child during the Plague",
			"Fled from Raventon after fire",
			"Survived the ambush at The Northern Pass"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Merchant",
			"Mood": "Calm",
			"Gender": "Male",
			"Age": "65",
			"Health": "Weak"
		},
		"History": [
			"Fled from Stonewatch after bandit raid",
			"Worked for a cruel captain before escaping",
			"Stole food during the Fire of Greymoor and was punished"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Blacksmith",
			"Mood": "Resigned",
			"Gender": "Male",
			"Age": "38",
			"Health": "Limping"
		},
		"History": [
			"Helped rebuild a village after the Border Conflict",
			"Spent years training under a master in Red Hill",
			"Lost everything in the fire"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Weaver",
			"Mood": "Hopeful",
			"Gender": "Male",
			"Age": "20",
			"Health": "Injured"
		},
		"History": [
			"Survived the ambush at Stonewatch",
			"Stole food during the Border Conflict and was punished",
			"Fled from Raventon after flood"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Fisherman",
			"Mood": "Worried",
			"Gender": "Male",
			"Age": "65",
			"Health": "Weak"
		},
		"History": [
			"Stole food during the Border Conflict and was punished",
			"Watched a loved one die during the Fire of Greymoor",
			"Protected a child during the Fire of Greymoor"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Stablehand",
			"Mood": "Paranoid",
			"Gender": "Male",
			"Age": "38",
			"Health": "Weak"
		},
		"History": [
			"Fled from Greymoor after bandit raid",
			"Survived the ambush at Raventon",
			"Spent years training under a master in Greymoor"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Herbalist",
			"Mood": "Hopeful",
			"Gender": "Male",
			"Age": "24",
			"Health": "Weak"
		},
		"History": [
			"Helped rebuild a village after the Fire of Greymoor",
			"Stole food during the Plague and was punished",
			"Was imprisoned after being accused of espionage"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Carpenter",
			"Mood": "Nervous",
			"Gender": "Male",
			"Age": "37",
			"Health": "Healthy"
		},
		"History": [
			"Protected a child during the Winter Siege",
			"Lost everything in the earthquake",
			"Spent years training under a master in Raventon"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Teacher",
			"Mood": "Calm",
			"Gender": "Male",
			"Age": "38",
			"Health": "Healthy"
		},
		"History": [
			"Survived the ambush at Greymoor",
			"Fled from Raventon after flood",
			"Was imprisoned after being accused of theft"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Weaver",
			"Mood": "Calm",
			"Gender": "Male",
			"Age": "57",
			"Health": "Bruised"
		},
		"History": [
			"Protected a child during the Plague",
			"Worked for a cruel abbot before escaping",
			"Survived the ambush at Stonewatch"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Teacher",
			"Mood": "Lonely",
			"Gender": "Male",
			"Age": "25",
			"Health": "Scarred"
		},
		"History": [
			"Helped rebuild a village after the Winter Siege",
			"Watched a loved one die during the Winter Siege",
			"Spent years training under a master in Raventon"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Teacher",
			"Mood": "Lonely",
			"Gender": "Male",
			"Age": "37",
			"Health": "Bruised"
		},
		"History": [
			"Survived the ambush at Raventon",
			"Fled from Greymoor after bandit raid",
			"Helped rebuild a village after the Harvest Famine"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Fisherman",
			"Mood": "Angry",
			"Gender": "Male",
			"Age": "34",
			"Health": "Bruised"
		},
		"History": [
			"Lost everything in the earthquake",
			"Spent years training under a master in The Northern Pass",
			"Survived the ambush at Stonewatch"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Soldier",
			"Mood": "Content",
			"Gender": "Male",
			"Age": "19",
			"Health": "Bruised"
		},
		"History": [
			"Lost everything in the flood",
			"Survived the ambush at Red Hill",
			"Worked for a cruel abbot before escaping"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Fisherman",
			"Mood": "Nervous",
			"Gender": "Male",
			"Age": "44",
			"Health": "Burned"
		},
		"History": [
			"Lost everything in the earthquake",
			"Was imprisoned after being accused of murder",
			"Protected a child during the Fire of Greymoor"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Hunter",
			"Mood": "Angry",
			"Gender": "Male",
			"Age": "45",
			"Health": "Limping"
		},
		"History": [
			"Lost everything in the fire",
			"Helped rebuild a village after the Harvest Famine",
			"Protected a child during the Winter Siege"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Merchant",
			"Mood": "Angry",
			"Gender": "Male",
			"Age": "38",
			"Health": "Healthy"
		},
		"History": [
			"Fled from Greymoor after fire",
			"Helped rebuild a village after the Plague",
			"Worked for a cruel abbot before escaping"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Soldier",
			"Mood": "Worried",
			"Gender": "Male",
			"Age": "39",
			"Health": "Scarred"
		},
		"History": [
			"Survived the ambush at Greymoor",
			"Lost everything in the flood",
			"Worked for a cruel noblewoman before escaping"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Hunter",
			"Mood": "Content",
			"Gender": "Male",
			"Age": "39",
			"Health": "Scarred"
		},
		"History": [
			"Protected a child during the Fire of Greymoor",
			"Spent years training under a master in The Northern Pass",
			"Fled from Raventon after fire"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Weaver",
			"Mood": "Resigned",
			"Gender": "Male",
			"Age": "55",
			"Health": "Weak"
		},
		"History": [
			"Helped rebuild a village after the Harvest Famine",
			"Protected a child during the Plague",
			"Spent years training under a master in Greymoor"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Blacksmith",
			"Mood": "Angry",
			"Gender": "Male",
			"Age": "27",
			"Health": "Weak"
		},
		"History": [
			"Worked for a cruel noblewoman before escaping",
			"Fled from The Northern Pass after flood",
			"Was imprisoned after being accused of murder"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Fisherman",
			"Mood": "Haunted",
			"Gender": "Male",
			"Age": "64",
			"Health": "Burned"
		},
		"History": [
			"Stole food during the Winter Siege and was punished",
			"Spent years training under a master in Greymoor",
			"Lost everything in the bandit raid"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Weaver",
			"Mood": "Paranoid",
			"Gender": "Male",
			"Age": "49",
			"Health": "Burned"
		},
		"History": [
			"Lost everything in the bandit raid",
			"Survived the ambush at The Northern Pass",
			"Was imprisoned after being accused of theft"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Stablehand",
			"Mood": "Hopeful",
			"Gender": "Male",
			"Age": "38",
			"Health": "Bruised"
		},
		"History": [
			"Protected a child during the Winter Siege",
			"Helped rebuild a village after the Winter Siege",
			"Fled from Raventon after bandit raid"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Hunter",
			"Mood": "Resigned",
			"Gender": "Male",
			"Age": "59",
			"Health": "Burned"
		},
		"History": [
			"Helped rebuild a village after the Plague",
			"Survived the ambush at Greymoor",
			"Worked for a cruel abbot before escaping"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Fisherman",
			"Mood": "Haunted",
			"Gender": "Male",
			"Age": "67",
			"Health": "Burned"
		},
		"History": [
			"Survived the ambush at Red Hill",
			"Lost everything in the earthquake",
			"Fled from Red Hill after fire"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Weaver",
			"Mood": "Worried",
			"Gender": "Male",
			"Age": "60",
			"Health": "Injured"
		},
		"History": [
			"Protected a child during the Harvest Famine",
			"Survived the ambush at Greymoor",
			"Watched a loved one die during the Winter Siege"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Blacksmith",
			"Mood": "Angry",
			"Gender": "Male",
			"Age": "26",
			"Health": "Bruised"
		},
		"History": [
			"Worked for a cruel captain before escaping",
			"Watched a loved one die during the Border Conflict",
			"Helped rebuild a village after the Harvest Famine"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Blacksmith",
			"Mood": "Content",
			"Gender": "Male",
			"Age": "21",
			"Health": "Bruised"
		},
		"History": [
			"Survived the ambush at The Northern Pass",
			"Spent years training under a master in Raventon",
			"Helped rebuild a village after the Plague"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Stablehand",
			"Mood": "Hopeful",
			"Gender": "Male",
			"Age": "19",
			"Health": "Bruised"
		},
		"History": [
			"Lost everything in the earthquake",
			"Stole food during the Harvest Famine and was punished",
			"Spent years training under a master in Red Hill"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Herbalist",
			"Mood": "Calm",
			"Gender": "Male",
			"Age": "28",
			"Health": "Healthy"
		},
		"History": [
			"Worked for a cruel lord before escaping",
			"Helped rebuild a village after the Border Conflict",
			"Survived the ambush at Red Hill"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Fisherman",
			"Mood": "Angry",
			"Gender": "Male",
			"Age": "34",
			"Health": "Healthy"
		},
		"History": [
			"Lost everything in the earthquake",
			"Stole food during the Border Conflict and was punished",
			"Protected a child during the Plague"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Weaver",
			"Mood": "Nervous",
			"Gender": "Male",
			"Age": "19",
			"Health": "Limping"
		},
		"History": [
			"Worked for a cruel noblewoman before escaping",
			"Helped rebuild a village after the Border Conflict",
			"Was imprisoned after being accused of treason"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Soldier",
			"Mood": "Nervous",
			"Gender": "Male",
			"Age": "30",
			"Health": "Limping"
		},
		"History": [
			"Watched a loved one die during the Plague",
			"Lost everything in the earthquake",
			"Spent years training under a master in The Northern Pass"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Blacksmith",
			"Mood": "Calm",
			"Gender": "Male",
			"Age": "40",
			"Health": "Weak"
		},
		"History": [
			"Stole food during the Harvest Famine and was punished",
			"Worked for a cruel noblewoman before escaping",
			"Watched a loved one die during the Plague"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Stablehand",
			"Mood": "Content",
			"Gender": "Male",
			"Age": "26",
			"Health": "Injured"
		},
		"History": [
			"Helped rebuild a village after the Border Conflict",
			"Spent years training under a master in Stonewatch",
			"Fled from The Northern Pass after earthquake"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Blacksmith",
			"Mood": "Content",
			"Gender": "Male",
			"Age": "64",
			"Health": "Healthy"
		},
		"History": [
			"Fled from Greymoor after fire",
			"Survived the ambush at Greymoor",
			"Stole food during the Fire of Greymoor and was punished"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Stablehand",
			"Mood": "Nervous",
			"Gender": "Male",
			"Age": "56",
			"Health": "Injured"
		},
		"History": [
			"Worked for a cruel noblewoman before escaping",
			"Helped rebuild a village after the Fire of Greymoor",
			"Spent years training under a master in Stonewatch"
		]
	},
	{
		"Info": {
			"Name": "",
			"Occupation": "Herbalist",
			"Mood": "Calm",
			"Gender": "Male",
			"Age": "35",
			"Health": "Scarred"
		},
		"History": [
			"Stole food during the Fire of Greymoor and was punished",
			"Lost everything in the earthquake",
			"Helped rebuild a village after the Harvest Famine"
		]
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
	print("VillagerAIInitializer: Updated latest news for all villagers: ", news_string)

func get_villager_info():
	var ChosenInfo = Villager_Info_Pool.pick_random()
	Villager_Info_Pool.erase(ChosenInfo)
	
	# Ensure Latest_news field exists and is an array
	if not ChosenInfo.has("Latest_news"):
		ChosenInfo["Latest_news"] = []
	elif typeof(ChosenInfo["Latest_news"]) == TYPE_STRING:
		ChosenInfo["Latest_news"] = [ChosenInfo["Latest_news"]] if ChosenInfo["Latest_news"] != "" else []
	
	# Eğer villager erkekse, ismini Osmanlı dönemi isim havuzundan seç
	if ChosenInfo.has("Info") and ChosenInfo["Info"].has("Gender"):
		var gender = ChosenInfo["Info"]["Gender"]
		if gender == "Male" and MALE_NAMES_OTTOMAN.size() > 0:
			var random_name = MALE_NAMES_OTTOMAN[randi() % MALE_NAMES_OTTOMAN.size()]
			ChosenInfo["Info"]["Name"] = random_name
			print("[VillagerAIInitializer] Erkek villager için Osmanlı dönemi ismi seçildi: %s" % random_name)
		else:
			# Gender "Male" değilse veya isim havuzu boşsa, yine de bir isim atanmalı (fallback)
			if not ChosenInfo["Info"].has("Name") or ChosenInfo["Info"]["Name"] == "":
				if MALE_NAMES_OTTOMAN.size() > 0:
					var random_name = MALE_NAMES_OTTOMAN[randi() % MALE_NAMES_OTTOMAN.size()]
					ChosenInfo["Info"]["Name"] = random_name
					ChosenInfo["Info"]["Gender"] = "Male"  # Gender'ı da düzelt
					print("[VillagerAIInitializer] İsimsiz villager için Osmanlı dönemi ismi seçildi: %s" % random_name)
		
	return ChosenInfo
	
const SAVE_DIR = "user://otto-man-save/"

func save_array_to_json(array: Array, file_name: String) -> void:
	# Ensure the save directory exists
	create_save_directory()

	# Construct the full path for the file
	var full_path = SAVE_DIR + file_name

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
		Villager_Info_Pool.erase(npc_data)
	Saved_Villagers = existing_villagers
	
func load_array_from_json(file_name: String) -> Array:
	# Construct the full path for the file
	var full_path = SAVE_DIR + file_name

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
	# Get a DirAccess instance
	var dir = DirAccess.open("user://")
	if dir:
		# Check if the "otto-man-save" directory exists within user://
		# Updated directory name here
		if not dir.dir_exists("otto-man-save"):
			# If not, create it
			# Updated directory name here
			var error = dir.make_dir("otto-man-save")
			if error != OK:
				push_error("Failed to create save directory: %s" % SAVE_DIR)
			else:
				print("Created save directory: %s" % SAVE_DIR)
		# Close the DirAccess instance
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
