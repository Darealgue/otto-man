extends Node

var Saved_Villagers : Array = []
var Villager_Info_Pool : Array =[
	{
		"Info": {
			"Name": "Hazel",
			"Occupation": "Fisherman",
			"Mood": "Angry",
			"Gender": "Female",
			"Age": "44",
			"Health": "Scarred"
		},
		"History": [
			"Helped rebuild a village after the Plague",
			"Was imprisoned after being accused of murder",
			"Worked for a cruel captain before escaping"
		]
	},
	{
		"Info": {
			"Name": "Beatrice",
			"Occupation": "Carpenter",
			"Mood": "Angry",
			"Gender": "Female",
			"Age": "65",
			"Health": "Burned"
		},
		"History": [
			"Was imprisoned after being accused of theft",
			"Survived the ambush at Raventon",
			"Helped rebuild a village after the Border Conflict"
		]
	},
	{
		"Info": {
			"Name": "Delilah",
			"Occupation": "Soldier",
			"Mood": "Content",
			"Gender": "Female",
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
			"Name": "Gareth",
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
			"Name": "Gareth",
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
			"Name": "Junia",
			"Occupation": "Weaver",
			"Mood": "Haunted",
			"Gender": "Female",
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
			"Name": "Alden",
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
			"Name": "Hazel",
			"Occupation": "Merchant",
			"Mood": "Resigned",
			"Gender": "Female",
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
			"Name": "Greta",
			"Occupation": "Hunter",
			"Mood": "Content",
			"Gender": "Female",
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
			"Name": "Harlan",
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
			"Name": "Isla",
			"Occupation": "Teacher",
			"Mood": "Lonely",
			"Gender": "Female",
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
			"Name": "Elise",
			"Occupation": "Teacher",
			"Mood": "Hopeful",
			"Gender": "Female",
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
			"Name": "Cora",
			"Occupation": "Weaver",
			"Mood": "Haunted",
			"Gender": "Female",
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
			"Name": "Cora",
			"Occupation": "Stablehand",
			"Mood": "Angry",
			"Gender": "Female",
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
			"Name": "Hazel",
			"Occupation": "Blacksmith",
			"Mood": "Lonely",
			"Gender": "Female",
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
			"Name": "Harlan",
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
			"Name": "Junia",
			"Occupation": "Stablehand",
			"Mood": "Calm",
			"Gender": "Female",
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
			"Name": "Harlan",
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
			"Name": "Cora",
			"Occupation": "Soldier",
			"Mood": "Nervous",
			"Gender": "Female",
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
			"Name": "Beatrice",
			"Occupation": "Fisherman",
			"Mood": "Resigned",
			"Gender": "Female",
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
			"Name": "Elias",
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
			"Name": "Dorian",
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
			"Name": "Isaac",
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
			"Name": "Alden",
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
			"Name": "Alden",
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
			"Name": "Cedric",
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
			"Name": "Dorian",
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
			"Name": "Finn",
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
			"Name": "Junia",
			"Occupation": "Hunter",
			"Mood": "Hopeful",
			"Gender": "Female",
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
			"Name": "Jude",
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
			"Name": "Isaac",
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
			"Name": "Harlan",
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
			"Name": "Dorian",
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
			"Name": "Anya",
			"Occupation": "Stablehand",
			"Mood": "Resigned",
			"Gender": "Female",
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
			"Name": "Delilah",
			"Occupation": "Blacksmith",
			"Mood": "Paranoid",
			"Gender": "Female",
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
			"Name": "Cedric",
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
			"Name": "Hazel",
			"Occupation": "Stablehand",
			"Mood": "Worried",
			"Gender": "Female",
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
			"Name": "Cora",
			"Occupation": "Carpenter",
			"Mood": "Haunted",
			"Gender": "Female",
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
			"Name": "Isla",
			"Occupation": "Fisherman",
			"Mood": "Haunted",
			"Gender": "Female",
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
			"Name": "Freya",
			"Occupation": "Blacksmith",
			"Mood": "Paranoid",
			"Gender": "Female",
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
			"Name": "Alden",
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
			"Name": "Cedric",
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
			"Name": "Anya",
			"Occupation": "Herbalist",
			"Mood": "Haunted",
			"Gender": "Female",
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
			"Name": "Finn",
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
			"Name": "Jude",
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
			"Name": "Beatrice",
			"Occupation": "Fisherman",
			"Mood": "Calm",
			"Gender": "Female",
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
			"Name": "Dorian",
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
			"Name": "Freya",
			"Occupation": "Carpenter",
			"Mood": "Paranoid",
			"Gender": "Female",
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
			"Name": "Anya",
			"Occupation": "Blacksmith",
			"Mood": "Haunted",
			"Gender": "Female",
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
			"Name": "Finn",
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
			"Name": "Dorian",
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
			"Name": "Delilah",
			"Occupation": "Teacher",
			"Mood": "Angry",
			"Gender": "Female",
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
			"Name": "Harlan",
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
			"Name": "Isla",
			"Occupation": "Fisherman",
			"Mood": "Nervous",
			"Gender": "Female",
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
			"Name": "Elias",
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
			"Name": "Elias",
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
			"Name": "Bran",
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
			"Name": "Elias",
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
			"Name": "Alden",
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
			"Name": "Hazel",
			"Occupation": "Teacher",
			"Mood": "Haunted",
			"Gender": "Female",
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
			"Name": "Gareth",
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
			"Name": "Junia",
			"Occupation": "Weaver",
			"Mood": "Hopeful",
			"Gender": "Female",
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
			"Name": "Harlan",
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
			"Name": "Greta",
			"Occupation": "Blacksmith",
			"Mood": "Resigned",
			"Gender": "Female",
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
			"Name": "Greta",
			"Occupation": "Weaver",
			"Mood": "Hopeful",
			"Gender": "Female",
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
			"Name": "Gareth",
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
			"Name": "Elise",
			"Occupation": "Stablehand",
			"Mood": "Paranoid",
			"Gender": "Female",
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
			"Name": "Elise",
			"Occupation": "Herbalist",
			"Mood": "Hopeful",
			"Gender": "Female",
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
			"Name": "Junia",
			"Occupation": "Carpenter",
			"Mood": "Nervous",
			"Gender": "Female",
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
			"Name": "Isaac",
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
			"Name": "Hazel",
			"Occupation": "Weaver",
			"Mood": "Calm",
			"Gender": "Female",
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
			"Name": "Cedric",
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
			"Name": "Cora",
			"Occupation": "Teacher",
			"Mood": "Lonely",
			"Gender": "Female",
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
			"Name": "Alden",
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
			"Name": "Cedric",
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
			"Name": "Cora",
			"Occupation": "Fisherman",
			"Mood": "Nervous",
			"Gender": "Female",
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
			"Name": "Hazel",
			"Occupation": "Hunter",
			"Mood": "Angry",
			"Gender": "Female",
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
			"Name": "Harlan",
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
			"Name": "Cora",
			"Occupation": "Soldier",
			"Mood": "Worried",
			"Gender": "Female",
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
			"Name": "Greta",
			"Occupation": "Hunter",
			"Mood": "Content",
			"Gender": "Female",
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
			"Name": "Anya",
			"Occupation": "Weaver",
			"Mood": "Resigned",
			"Gender": "Female",
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
			"Name": "Isla",
			"Occupation": "Blacksmith",
			"Mood": "Angry",
			"Gender": "Female",
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
			"Name": "Freya",
			"Occupation": "Fisherman",
			"Mood": "Haunted",
			"Gender": "Female",
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
			"Name": "Beatrice",
			"Occupation": "Weaver",
			"Mood": "Paranoid",
			"Gender": "Female",
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
			"Name": "Jude",
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
			"Name": "Elias",
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
			"Name": "Jude",
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
			"Name": "Harlan",
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
			"Name": "Jude",
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
			"Name": "Alden",
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
			"Name": "Cora",
			"Occupation": "Stablehand",
			"Mood": "Hopeful",
			"Gender": "Female",
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
			"Name": "Anya",
			"Occupation": "Herbalist",
			"Mood": "Calm",
			"Gender": "Female",
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
			"Name": "Isaac",
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
			"Name": "Bran",
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
			"Name": "Hazel",
			"Occupation": "Soldier",
			"Mood": "Nervous",
			"Gender": "Female",
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
			"Name": "Jude",
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
			"Name": "Isaac",
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
			"Name": "Junia",
			"Occupation": "Blacksmith",
			"Mood": "Content",
			"Gender": "Female",
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
			"Name": "Alden",
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
			"Name": "Anya",
			"Occupation": "Herbalist",
			"Mood": "Calm",
			"Gender": "Female",
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
signal LoadComplete

func _ready() -> void:
	randomize()

func get_villager_info():
	var ChosenInfo = Villager_Info_Pool.pick_random()
	Villager_Info_Pool.erase(ChosenInfo)
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
	var ExistingVillagers = load_array_from_json("Saved_Villagers.json")
	for NPCdata in ExistingVillagers:
		Villager_Info_Pool.erase(NPCdata)
	Saved_Villagers = ExistingVillagers
	
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
		if result is Array:
			print("Successfully loaded data from: %s" % full_path)
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
