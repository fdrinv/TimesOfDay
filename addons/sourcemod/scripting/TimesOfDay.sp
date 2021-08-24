  // Main Include
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>

// Сustom Include
#include <colors>           // - https://hlmod.ru/resources/colors-inc-cveta-csgo-css-css-v34.2358/ - Кроссплатформенность.
#include <autoexecconfig>   // - https://forums.alliedmods.net/showthread.php?t=204254 - Мобильность.


// Plugin Define
#define PLUGIN_VERSION              "1.0.0"
#define PLUGIN_AUTHOR 	            "DENFER"

// Plugin Constans
#define MIDNIGHT                    240000
#define NOON                        120000

// Compile options  
#pragma newdecls required
#pragma semicolon 1

// Handle 
ConVar  gc_sPrefix[64],
        gc_bMessages,
        gc_bOwnTime,
        gc_sOwnTime[8];

// String
char    g_sServerTime[16],
        g_sPrefix[64],
        g_sPathPreferencesKeyValues[PLATFORM_MAX_PATH];
        g_sPreferenceTime[8],
        g_sPreferenceServerTime[8];

// Float
float g_flDailyDensityFog[12];

// Int
int     g_iFogIndex,
        g_iServerTime;

// Bool
bool    g_bCreatedFog;

// Information
public Plugin myinfo = {
	name = "TimesOfDay",
	author = "DENFER (for all questions - https://vk.com/denferez)",
	version = PLUGIN_VERSION,
};

//******************************************************//
//                                                      //
//                        STARTUP                       //
//                                                      //
//******************************************************//


public void OnPluginStart() 
{
    // Translation
	LoadTranslations("TimesOfDay.phrases");

    // AutoExecConfig
    AutoExecConfig_SetCreateDirectory(true);
    AutoExecConfig_SetCreateFile(true);
    AutoExecConfig_SetFile("TimesOfDay", PLUGIN_AUTHOR);

    // ConVars 
    gc_bMessages    = AutoExecConfig_CreateConVar("sm_tod_messages",         "1",                    "Включить сообщения плагина? (1 - вкл., 0 - выкл.)", 0, true, 0.0, true, 1.0);
    gc_sPrefix      = AutoExecConfig_CreateConVar("sm_tod_prefix",           "[{green}SM{default}]", "Префикс перед сообщениями плагина?");
    gc_bOwnTime     = AutoExecConfig_CreateConVar("sm_tod_own_time_mode",    "0",                    "Использовать собственное время? Иначе будет использоваться серверное время. (1 - исп, 0 - не исп.)", 0, true, 0.0, true, 1.0);
    gc_sOwnTime     = AutoExecConfig_CreateConVar("sm_tod_own_time",         "12:00",                "Укажите время, с которого начнется отсчет после первого запуска сервера. Указывать в формате hh:mm. (час:минуты)");

    // Hooks 
    HookEvent("round_start", Event_OnRoundStart);

    // AutoExecConfig
    AutoExecConfig_ExecuteFile();
    AutoExecConfig_CleanFile(); 
}

//******************************************************//
//                                                      //
//                  SOURCEMOD CALLBACKS                 //
//                                                      //
//******************************************************//

public void OnMapStart() 
{
    // Создаем сущность - туман, она идеально подходит для имитации времени суток 
    if (CreateEntity(g_iFogIndex, "env_fog_controller")) 
	{
		SettingsFog(); // устанавливаем соотвутствующие настройки тумана
		DispatchSpawn(g_iFogIndex); // спавним на карте сущность
	}
	else // если сущность уже предусмотрена картой
	{	
		g_bCreatedFog = true; 
	}
}

public void OnConfigsExecuted() 
{
    // Инициализация префикса плагина
    gc_sPrefix.GetString(g_sPrefix, sizeof(g_sPrefix));

    // Проверка преференса плагина 
    if (gc_bOwnTime.BoolValue)
    {
        KeyValues hPreferences = new KeyValues("Preferences");
		hPreferences.Rewind(); // Preferences
	
        // Создаем путь к файлу, т.к. в дальнейшем еще будем им пользоваться
        BuildPath(Path_SM, g_sPathPreferencesKeyValues, sizeof(g_sPathPreferencesKeyValues), "configs/DENFER/TimesOfDay/preferences.cfg");
        
        if (hPreferences.ImportFromFile(g_sPathPreferencesKeyValues))
        {
            char buffer[4];
            hPreferences.GetString("first_init", buffer, sizeof(buffer));

            // Если плагин впервые запускается с собственным временнем, которое было выставлено владельцем плагина, 
            // то стоит сообщить о том, что плагин будет 'существовать' и работать по-своему времени, отличающемуся от серверного.
            if (!strcmp(buffer, "yes"))
            {
                hPreferences.SetString("first_init", "no");
            }
            else
            {
                // Вынимаем строку с сохраненным временем на момент выключения сервера и строку с серверным временем
                hPreferences.GetString("current_time", g_sPreferenceTime, sizeof(g_sPreferenceTime));
                hPreferences.GetString("server_time", g_sPreferenceServerTime, sizeof(g_sPreferenceServerTime));
            }
        }
        
		delete hPreferences;
    }
}

public void OnMapEnd() 
{

}

public void OnPluginEnd() 
{
    // Сохранение в преференс
    if (gc_bOwnTime.BoolValue)
    {
        KeyValues hPreferences = new KeyValues("Preferences");
		hPreferences.Rewind(); // Preferences

        if(hPreferences.ImportFromFile(g_sPathPreferencesKeyValues))
        {
            char buffer[8];
            GetServerTimeString(buffer, sizeof(buffer));

            hPreferences.SetString("current_time", buffer);
            hPreferences.SetString("server_time", buffer);
        }
    }
}

public void OnGameFrame() 
{

}

//******************************************************//
//                                                      //
//                         HOOKS                        //
//                                                      //
//******************************************************//
void Event_OnRoundStart(Event event, const char[] name, bool dontBroadcast) 
{	
    if(g_bCreatedFog) // если сущность была предусмотрена картой 
	{
		SettingsFog();
	}
}

//******************************************************//
//                                                      //
//                         EVENTS                       //
//                                                      //
//******************************************************//

//******************************************************//
//                                                      //
//                      FUNCTIONS                       //
//                                                      //
//******************************************************//

public bool CreateEntity(int &index, const char[] name)
{
    if(FindEntityByClassname(-1, name) != -1) // проверяем наличие сущности на карте
    {
        return false;
    }
    
    index = CreateEntityByName(name);

    if(IsValidEntity(index)) // если сущность была создана
    {
        return true;
    }

    return false;
}

public void SettingsFog()
{
    // Стандарные параметры, которые не требуется изменять
    DispatchKeyValue(g_iFogIndex, "targetname", "Fog");
	DispatchKeyValue(g_iFogIndex, "fogenable", "1");
	DispatchKeyValue(g_iFogIndex, "spawnflags", "1");
	DispatchKeyValue(g_iFogIndex, "fogblend", "0");
	DispatchKeyValue(g_iFogIndex, "fogcolor", "0 0 0");
	DispatchKeyValue(g_iFogIndex, "fogcolor2", "0 0 0");
	DispatchKeyValueFloat(g_iFogIndex, "fogstart", 0.0);
	DispatchKeyValueFloat(g_iFogIndex, "fogend", 50.0);

    // flMaxDensity - плотность тумана, создает иллюзию ночи
public float fogmaxdensity = 0.0

    // Так как плагин не пользуется точными научными данными в зависимости от дня и месяца
    // пришлость взять строгие границы, а именно 12:00 - полдень (солнце находится в зените)
    // и это самая яркая точка. 
    // 00:00  - солнце полностью зашло, максимальная плотность. 

    fogmaxdensity = GetFogMaxDestiny()
	DispatchKeyValueFloat(g_iFogIndex, "fogmaxdensity", fogmaxdensity);
}

/**
*   Переводит из формата даты в целочисленное значение.
*
*   @param time - строка в формате времени %H:%M:%S.
*   @param size - размер строки со временем.
*
*   @return     - целочисленное значение типа Int (интовое представление времени).
*/
public int TimeToInt(char[] time, const char size) 
{
    // Удаляем не нужные символы ':', превращая строку в формат hh:mm:ss
    ReplaceString(time, size, ":", "");
    // Конвертирую в тип Int, стоит подметить, что крайний левый ноль пропадет. 
    return StringToInt(time);
}

/**
*   Переводит из целочисленного значения в формат времени.
*
*   @param number   - число типа Int.
*   @param buffer   - буффер для хранения времени.
*   @param size     - размер буффера.
*
*   @return         - ничего не возвращает.
*/
public void IntToTime(int number, char[] buffer, const int size)
{
    // На данный момент плагин поддерживает только 24 часовой формат, поэтому были заведены строгие границы области значения number.
    if (number < 0 || number > 2359) 
    {
        return;
    }

    // Дальше интовое значение числа нам не пригодится
    IntToString(number, buffer, size);

    // Если число было передано без 0 - добавим его для стандартного представления времени - 0h:mm:ss
    if (strlen(buffer) == 5)
    {
        FormatEx(buffer, size, "0%s");
    }

    // Создаем еще один копирующий буффер
    char copyBuffer[8];
    int counter = 0, counter_buffer = 0;

    while (counter != 8)
    {
        if (counter == 2)
        {
            copyBuffer[counter] = ':';
        }
        else 
        {
            copyBuffer[counter] = buffer[counter_buffer];
            ++counter_buffer;
        }

        LogError("%s", copyBuffer[counter]);
        ++counter;
    }

    FormatEx(buffer, size, "%s", copyBuffer);
}

/**
*   Получает серверное время формата HH:MM и сохраняет в буффере.
*   
*   @param buffer   - буффер для хранения времени.
*   @param size     - размер буффера.
*
*   @return         - ничего не возвращает.
*/
public void GetServerTimeString(char[] buffer, const int size)
{
    // Получаем время в формате hh:mm:ss 
    FormatTime(buffer, size, "%H:%M");
}

/**
*   Получает серверное время представленное в виде числа Int.
*   
*   @return         - число типа Int.
*/
public int GetServerTimeInt()
{
    char time[16];
    FormatTime(time, sizeof(time), "%H:%M");

    return TimeToInt(time);
}

/**
*   Возвращает плотность тумана в зависимости от времени на сервере.
*
*   @return     - плотность тумана.
*/
public float GetFogMaxDestiny()
{
    int time = GetServerTimeInt();
    float fogmaxdensity = 0.0;

    // Процесс заката, от самого ярко к темному, то бишь с 12:00 до 00:00
    if (time >= NOON && time < MIDNIGHT)
    {
        fogmaxdensity = g_flDailyDensityFog[GetIndexDailyDensityFog(time)];
    }

    // Процесс рассвета, от самого темного к яркому, то бишь с 00:00 до 12:00 
    if(time < NOON)
    {
        fogmaxdensity = g_flDailyDensityFog[GetIndexDailyDensityFog(time)];
    }

    return fogmaxdensity;
}

/**
*   //TODO: Дописать функцию и придумать методы вычитания и сложения времени.
*   Получает собственное серверное время формата HH:MM и сохраняет в буффере.
*   
*   @param buffer   - буффер для хранения времени.
*   @param size     - размер буффера.
*
*   @return         - ничего не возвращает.
*/
void GetOwnServerTimeString(char[] buffer, const int size) 
{
    // Конвертируем наше время в Int
    int ownTime = TimeToInt(g_sPreferenceTime, sizeof(g_sPreferenceTime));
    int serverTime = GetServerTimeInt();

}

//TODO: Написать метод вычитания двух временных точек.
void TimeSub()
{

}

//TODO: Написать метод сложения двух временных точек.
void TimeAdd()
{

}

public void GeneratorDailyDensityFog()
{
    // Инициализируем минимум и максимум плотности тумана
    g_flDailyDensityFog[0] = 0.0; g_flDailyDensityFog[11] = 1.0;

    // Исключаем первый и последний час, так как в они являются минимумом и максимом соответственно 
    for (int i = 1; i < sizeof(g_flDailyDensityFog) - 1; ++i)
    {
        g_flDailyDensityFog[i] = g_flDailyDensityFog[i - 1] + 0.093;
    }
}

/**
*   Получает индекс элемента массива содержащий плотность тумана в зависимости от времени суток.
*
*   @param time     - серверное время в формате Int.
*
*   @return         - индекс элемента массива или -1, если время не попадает в соответсвющий суточный промежуток. 
*/
public int GetIndexDailyDensityFog(int time)
{
    for (int i = 0, add = 0; i < sizeof(g_flDailyDensityFog); ++i, add += 10000)
    {
        // 00:00 до 12:00
        if (time >= 0 + add && time < 10000 + add)
        {
            return i;
        }

        // 12:00 до 24:00
        if (time >= 120000 + add && time < 130000 + add)
        {
            return i;
        }
    }

    return -1;
}
