// Version: 1.0.2

#if defined _colors_included
#endinput
#endif
#define _colors_included

#define SAY_TEXT2_NEED 'w' + 'S'

#define MENU 		-2	// Сообщение возвращается с вырезанными цветами и никому не отправляется
#define ALL	 		-1	// Сообщение в чат для всех игроков
#define SERVER	 	0	// Сообщение в консоль сервера

/**
 * Отправить сообщение в чат или консоль сервера
 * 
 * @param client  	Индекс игрока или MENU/ALL/SERVER
 * 
 * @param phrase	Фраза, которая должная быть переведена, или "", если перевод не требуется.
 *					Если фраза не переведена, то ошибки не будет, а вместо перевода отобразится фраза.
 * 
 * @param format	Правила форматирования, или "".
 * 
 * 					Если в переводе нет переменных, то рекомендуется писать так:
 *					CPrintTo(client, "my phrase"); // В этом случае сработает FormatEx %T, "my phrase", client (быстрее, чем SetGlobalTransTarget + VFormat).
 *
 *					Если переменные есть, то пишите так:
 *					CPrintTo(client, "my phrase", "%t", "my phrase", var1, var2); // Именно %t (так короче), а не %T. Это сработает, т.к. делается SetGlobalTransTarget.
 *
 *					Если перевод не нужен:
 *					CPrintTo(client, _, "{default}Hi, {team}%N", client);
 *
 *					Если текст нужен для меню, то чтобы вырезать цвета из перевода, используйте:
 *					panel.DrawText(CPrintTo(MENU, "your hp", "%T", "your hp", client, GetClientHealth(client)));
 *
 * @return			Последнее отредактированное отправленное сообщение или "".
 */
stock char[] CPrintTo(int client, const char[] phrase="", const char[] format="", any ...)
{
	static char s[512];
	static StringMap trie = null;
	static EngineVersion engine ;
	static int iServerLanguage	;
	
	if(!trie)
	{
		trie = new StringMap();
		
		switch ((engine = GetEngineVersion())) {
			case Engine_CSGO:
			{
				trie.SetValue("red"			, 0x02);
				trie.SetValue("lightred"	, 0x07);
				trie.SetValue("blue"		, 0x0C);
				trie.SetValue("lightblue"	, 0x0B);
				trie.SetValue("lightgreen"	, 0x05);
				trie.SetValue("lime"		, 0x06);
				trie.SetValue("yellow"		, 0x09);
				trie.SetValue("orange"		, 0x10);
				trie.SetValue("pink"		, 0x0E);
				trie.SetValue("purple"		, 0x03);
				trie.SetValue("gray"		, 0x0A);
			}
			case Engine_CSS:
			{
				trie.SetValue("lightgreen"	, 0x03);
				trie.SetValue("darkgreen"	, 0x05);
			}
			case Engine_SourceSDK2006: {
				trie.SetValue("lightgreen"	, 0x03);
			}
			default: {
				SetFailState("This game not supported");
			}
		}
		
		trie.SetValue("default"	, 0x01);
		trie.SetValue("green"	, 0x04);
		trie.SetValue("team"	, 0x03);
		
		iServerLanguage = GetServerLanguage();
	}
	
	if (!phrase[0] && !format[0]) {
		return s;
	}
	
	bool translationError = phrase[0] && !IsTranslatedForLanguage(phrase, iServerLanguage);
	if ( translationError) {
		strcopy(s, sizeof(s), phrase);
	}
	else{
		s[0] = 0;
	}
	
	for (int target = 1, bytes, c; target <= MaxClients; ++target) {
		if (client == ALL) {
			if (!IsClientInGame(target)/* || IsFakeClient(target) */|| IsClientInKickQueue(target)) {
				continue;
			}
		}
		else if ((target = client) > 0) {
			if (target > MaxClients) {
				continue;
			}
		}
		else if (target != SERVER && target != MENU)
		{
			s[0] = 0;
			return s;
		}
		
		int team = 0;
		
		if (!translationError) {
			// Т.к. FormatEx быстрее, чем VFormat, то используем его когда можно.
			if (format[0]) {
				if (phrase[0] && target != MENU) {
					SetGlobalTransTarget(target); // Полезно только если используется "%t". SERVER = LANG_SERVER = 0.
				}
				bytes = VFormat (s, sizeof(s), format, 4);
			}
			else{
				// - user: "Пф, а зачем нули а?"
				// - dev : "Если в переводе есть переменные, но их нет в Format, то будет ошибка, а так не будет, пони а?"
				// - user: "А, ну ок а."
				bytes = FormatEx(s, sizeof(s), "%T", phrase, (target == MENU ? LANG_SERVER : target), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
			}
			// Поиск/замена цветов. Такой вариант должен быть быстрее, чем ReplaceString.
			if (bytes > 5) // "{red}" 5
			{
				int i = -1, i_start = -1;
				bool replaced = false;
				
				while (++i < bytes ) {
					if (s[i] == '{') {
						i_start = i;
					}
					else if (s[i] == '}' ) {
						if (i_start != -1) {
							int i_end = i;
							
							// "{lightgreen}" 12, "{#FFFFFF}" 9
							if ((i_end - i_start) < 12 && (s[i_start+1] != '#' || ((i_end - i_start) == 8 && engine == Engine_CSS))) {
								if (s[i_start+1] == '#') {
									if (target == SERVER || target == MENU) {
										while (i_start <= i_end) {
											s[i_start++] = 0; // Цвета не нужны
										}
									}
									else{
										// "{#FFFFFF}"="0\x07FFFFFF0"
										s[i_start	] = 0;
										s[i_start+1	] = 0x07;
										s[i_end		] = 0;
									}
									replaced = true;
								}
								else{
									s[i_end] = 0;
									if (trie.GetValue(s[i_start+1], c)) {
										// Цвет поддерживается
										if (target == SERVER || target == MENU) {
											while (i_start <= i_end) {
												s[i_start++] = 0; // Цвета не нужны
											}
										}
										else{
											if (c == 0x03 && s[i_start+1] == 't') {
												// {team}
												if (engine == Engine_CSGO) {
													switch (team ? team : (team = GetClientTeam(target))) {
														case 2: {
															c = 0x09; // t
														}
														case 3: {
															c = 0x0B; // ct
														}
														default: {
															c = 0x02; // spec
														}
													}
												}
												else{
													team = SAY_TEXT2_NEED;
												}
											}
											// "{red}Msg" = "0000\x02Msg"
											while (i_start < i_end) {
												s[i_start++] = 0;
											}
											s[i_end] = c;
										}
										replaced = true;
									}
									else{
										// Цвет не поддерживается. Это может быть {userid} и тд, поэтому не очищаем (на всякий).
										s[i_end] = '}' ;
									}
								}
							}
							
							i_start = -1; // Снова ищем '{', игнорируя '}'.
						}
					}
				}
				
				if (replaced) {
					// Сдвигаем всё влево, удаляя ненужные символы конца строки.
					i = -1;
					while (++i < bytes) {
						if (!s[i]) {
							c = i;
							while (++c < bytes) {
								if (s[c]) {
									s[i] = s[c];
									s[c] = 0;
									break;
								}
							}
							if (!s[i]) {
								break; // Справа одни нули
							}
						}
					}
				}
			}
		}
	
		if (s[0]) {
			if (target == MENU) {
				return s;
			}
			if (target == SERVER) {
				PrintToServer("%s", s);
			}
			else if (team == SAY_TEXT2_NEED)
			{
				// css + css v34
				int players[1];
				players[0]  = target;
				Handle hMsg = StartMessage("SayText2", players, 1);
				if (hMsg) {
					if (s[0] != 0x01) {
						Format(s, sizeof(s), "\x01%s", s);
					}
					BfWriteByte  (hMsg, target);
					BfWriteByte  (hMsg, true);
					BfWriteString(hMsg, s);
					EndMessage();
				}
				else{
					PrintToChat(target, "%s%s", (s[0] == 0x01 ? "" : "\x01"), s);
				}
			}
			else{
				PrintToChat(target, "%s%s", (s[0] == 0x01 ? "" : "\x01"), s);
				if (engine == Engine_CSGO) {
					// В css если отправить сообщение в чат, то оно отображается и в консоле, но в csgo это не так.
					PrintToConsole(target, "%s", s);
				}
			}
		}
		
		if (client != ALL) {
			break;
		}
	}
	
	return s;
}