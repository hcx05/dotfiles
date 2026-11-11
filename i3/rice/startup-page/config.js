// ╔╗ ╔═╗╔╗╔╔╦╗╔═╗
// ╠╩╗║╣ ║║║ ║ ║ ║
// ╚═╝╚═╝╝╚╝ ╩ ╚═╝
// ┌─┐┌─┐┌┐┌┌─┐┬┌─┐┬ ┬┬─┐┌─┐┌┬┐┬┌─┐┌┐┌
// │  │ ││││├┤ ││ ┬│ │├┬┘├─┤ │ ││ ││││
// └─┘└─┘┘└┘└  ┴└─┘└─┘┴└─┴ ┴ ┴ ┴└─┘┘└┘

const CONFIG = {
	// ┌┐ ┌─┐┌─┐┬┌─┐┌─┐
	// ├┴┐├─┤└─┐││  └─┐
	// └─┘┴ ┴└─┘┴└─┘└─┘

	// General
	name: 'kali',
	imageBackground: false,
	openInNewTab: true,
	twelveHourFormat: true,
	timeZone: 'Asia/Taipei',

	// Greetings
	greetingMorning: 'Good morning!',
	greetingAfternoon: 'Good afternoon,',
	greetingEvening: 'Good evening,',
	greetingNight: 'Go to Sleep!',

	// Layout
	bentoLayout: 'lists', // 'bento', 'lists', 'buttons'

	// Weather
	weatherKey: '8b05d62206f459e1d298cbe5844d7d87', // Write here your API Key
	weatherIcons: 'OneDark', // 'Onedark', 'Nord', 'Dark', 'White'
	weatherUnit: 'C', // 'F', 'C'
	language: 'en', // More languages in https://openweathermap.org/current#multi

	trackLocation: false, // Use Taipei coordinates directly (avoids geolocation block & VPN IP mismatch)
	defaultLatitude: '25.0330',
	defaultLongitude: '121.5654',

	// Autochange
	autoChangeTheme: false,

	// Autochange by OS
	changeThemeByOS: true,

	// Autochange by hour options (24hrs format, string must be in: hh:mm)
	changeThemeByHour: false,
	hourDarkThemeActive: '18:30',
	hourDarkThemeInactive: '07:00',

	// ┌┐ ┬ ┬┌┬┐┌┬┐┌─┐┌┐┌┌─┐
	// ├┴┐│ │ │  │ │ ││││└─┐
	// └─┘└─┘ ┴  ┴ └─┘┘└┘└─┘

	firstButtonsContainer: [
		{
			id: '1',
			name: 'Github',
			icon: 'github',
			link: 'https://github.com/',
		},
		{
			id: '2',
			name: 'E-Mail',
			icon: 'mail',
			link: 'https://mail.protonmail.com/',
		},
		{
			id: '3',
			name: 'To-Do',
			icon: 'trello',
			link: 'https://todoist.com',
		},
		{
			id: '4',
			name: 'Calendar',
			icon: 'calendar',
			link: 'https://calendar.google.com/calendar/r',
		},
		{
			id: '5',
			name: 'Reddit',
			icon: 'glasses',
			link: 'https://reddit.com',
		},
		{
			id: '6',
			name: 'YouYube',
			icon: 'youtube',
			link: 'https://odysee.com/',
		},
	],

	secondButtonsContainer: [
		{
			id: '1',
			name: 'z0mbi3',
			icon: 'headphones',
			link: 'https://open.spotify.com',
		},
		{
			id: '2',
			name: 'z0mbi3',
			icon: 'twitter',
			link: 'https://twitter.com/',
		},
		{
			id: '3',
			name: 'z0mbi3',
			icon: 'bot',
			link: 'https://discord.com/app',
		},
		{
			id: '4',
			name: 'z0mbi3',
			icon: 'shopping-bag',
			link: 'https://amazon.com/',
		},
		{
			id: '5',
			name: 'z0mbi3',
			icon: 'pen-tool',
			link: 'https://hashnode.com/',
		},
		{
			id: '6',
			name: 'z0mbi3',
			icon: 'figma',
			link: 'https://figma.com/',
		},
	],

	// ┬  ┬┌─┐┌┬┐┌─┐
	// │  │└─┐ │ └─┐
	// ┴─┘┴└─┘ ┴ └─┘

	// First Links Container
	firstlistsContainer: [
		{
			icon: 'star',
			id: '1',
			links: [
				{
					name: 'GitHub',
					link: 'https://github.com/',
				},
				{
					name: 'Gemini',
					link: 'https://gemini.google.com/',
				},
				{
					name: 'ChatGPT',
					link: 'https://chatgpt.com/',
				},
				{
					name: 'Claude',
					link: 'https://claude.ai/',
				},
			],
		},
		{
			icon: 'tv',
			id: '2',
			links: [
				{
					name: 'YouTube',
					link: 'https://www.youtube.com/',
				},
				{
					name: 'Instagram',
					link: 'https://www.instagram.com/',
				},
				{
					name: 'X',
					link: 'https://x.com/home',
				},
				{
					name: 'Telegram',
					link: 'https://web.telegram.org/',
				},
			],
		},
	],

	// Second Links Container
	secondListsContainer: [
		{
			icon: 'shield',
			id: '1',
			links: [
				{
					name: 'HTB Academy',
					link: 'https://academy.hackthebox.com/',
				},
				{
					name: 'TryHackMe',
					link: 'https://tryhackme.com/',
				},
				{
					name: 'pwn.college',
					link: 'https://pwn.college/',
				},
				{
					name: 'The Hacker Recipes',
					link: 'https://www.thehacker.recipes/',
				},
			],
		},
		{
			icon: 'binary',
			id: '2',
			links: [
				{
					name: 'GeeksforGeeks',
					link: 'https://www.geeksforgeeks.org/',
				},
				{
					name: 'Coddy.tech',
					link: 'https://coddy.tech/',
				},
				{
					name: 'MonkeyType',
					link: 'https://monkeytype.com/',
				},
				{
					name: 'arXiv',
					link: 'https://arxiv.org/',
				},
			],
		},
	],
};
