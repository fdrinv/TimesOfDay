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

// String
char g_sServerTime[16];

// Float
float g_flDailyDensityFog[12];

// Int
int g_iFogIndex,
    g_iServerTime;

// Bool
bool g_bCreatedFog;

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

    // Commands 
    RegConsoleCmd("sm_time", Test);

    // ConVars 

    // Hooks 
    HookEvent("round_start", Event_OnRoundStart);

    // AutoExecConfig
    AutoExecConfig_ExecuteFile();
    AutoExecConfig_CleanFile(); 

    GeneratorDailyDensityFog();

    char buffer[16];
    GetServerTimeString(buffer, 16);

    LogError("Time to string = %s, time to int = %i", buffer, GetServerTimeInt());
    LogError("This is daily densite fog index = %i", GetIndexDailyDensityFog(TimeToInt(buffer, 16)));
    LogError("This is densite = %f", GetFogMaxDestiny());
}

public Action Test(int client, int args)
{
    char buffer[16];
    GetServerTimeString(buffer, 16);

    CPrintTo(ALL, "Time to string = %s, time to int = %i", buffer, GetServerTimeInt());
    PrintToChatAll("This is daily densite fog index = %i", GetIndexDailyDensityFog(TimeToInt(buffer, 16)));
    PrintToChatAll("This is densite = %f", GetFogMaxDestiny());


    return Plugin_Handled;
}

//******************************************************//
//                                                      //
//                  SOURCEMOD CALLBACKS                 //
//                                                      //
//******************************************************//


public void OnMapStart() 
{
    // Создаем сущность - туман, она идеально подходит для имитации времени суток 
    if(CreateEntity(g_iFogIndex, "env_fog_controller")) 
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

}

public void OnMapEnd() 
{

}

public void OnPluginEnd() 
{

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
    float fogmaxdensity = 0.0;

    // Так как плагин не пользуется точными научными данными в зависимости от дня и месяца
    // пришлость взять строгие границы, а именно 12:00 - полдень (солнце находится в зените)
    // и это самая яркая точка. 
    // 00:00  - солнце полностью зашло, максимальная плотность. 
    // TODO: Сделать поддержку по месяцам и дням, и максимально приблизить к естественным явлениям заката и восхода. 

    fogmaxdensity = GetFogMaxDestiny();
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
    if (number < 0 || number > 235959) 
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
    char copyBuffer[16];
    int counter = 0, counter_buffer = 0;

    while (counter != 8)
    {
        if (counter == 2 || counter == 5)
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
*   Получает серверное время формата HH:MM:SS и сохраняет в буффере.
*   
*   @param buffer   - буффер для хранения времени.
*   @param size     - размер буффера.
*
*   @return         - ничего не возвращает.
*/
public void GetServerTimeString(char[] buffer, const int size)
{
    // Получаем время в формате hh:mm:ss 
    FormatTime(buffer, size, "%H:%M:%S");
}

/**
*   Получает серверное время представленное в виде числа Int.
*   
*   @return         - число типа Int.
*/
public int GetServerTimeInt()
{
    char time[16];
    FormatTime(time, sizeof(time), "%H:%M:%S");

    return TimeToInt(time, sizeof(time));
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
*   Генирирует плотность тумана в зависимости от времени суток. 
*
*   @return     - ничего не возвращает.
*/
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