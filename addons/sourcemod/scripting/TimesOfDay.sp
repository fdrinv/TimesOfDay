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
#define MIDNIGHT                    2400
#define NOON                        1200

// Compile options  
#pragma newdecls required
#pragma semicolon 1
#pragma tabsize 0 

// Handle 
ConVar  gc_sPrefix,
        gc_bMessages,
        gc_bOwnTime,
        gc_sOwnTime;

// String
char    g_sServerTime[16],
        g_sPrefix[64],
        g_sPathPreferencesKeyValues[PLATFORM_MAX_PATH],
        g_sPreferenceOwnTime[8],
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
            if (!strcmp(buffer, "no"))
            {
                hPreferences.SetString("first_init", "yes");
            }
            else
            {
                // Вынимаем строку с сохраненным временем на момент выключения сервера и строку с серверным временем
                hPreferences.GetString("own_time", g_sPreferenceOwnTime, sizeof(g_sPreferenceOwnTime));
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
    // Сохранение в преференс, если плагин был отключен 
    if (gc_bOwnTime.BoolValue)
    {
        UpdatePreferences();
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
    // Сохранение в преференс
    // TODO: Удостоверится в том, что это оптимально и имеет смысл быть 
    if (gc_bOwnTime.BoolValue)
    {
        UpdatePreferences();
    }

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

    fogmaxdensity = GetFogMaxDestiny();
	DispatchKeyValueFloat(g_iFogIndex, "fogmaxdensity", fogmaxdensity);
}

/**
*   Переводит из формата даты в целочисленное значение.
*
*   @param time - строка в формате времени %H:%M.
*   @param size - размер строки со временем.
*
*   @return     - целочисленное значение типа Int (интовое представление времени).
*/
public int TimeToInt(char[] time, const char size) 
{
    // Удаляем не нужные символы ':', превращая строку в формат hh:mm
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

    // Если число было передано без 0 - добавим его для стандартного представления времени - 0h:mm
    // Создаем еще один копирующий буффер
    char copyBuffer[8];

    // 0h:mm
    if (strlen(buffer) == 3)
    {
        copyBuffer[0] = '0';

        for (int i = 0; i < sizeof(copyBuffer) - 1; ++i)
        {
            copyBuffer[i + 1] = buffer[i];
        }

        for (int i = 0; i < size; ++i)
        {
            buffer[i] = copyBuffer[i];
        }
    }

    // 00:mm
    if (strlen(buffer) == 2)
    {
        copyBuffer[0] = '0';
        copyBuffer[1] = '0';

        for (int i = 0; i < sizeof(copyBuffer) - 2; ++i)
        {
            copyBuffer[i + 2] = buffer[i];
        }

        for (int i = 0; i < size; ++i)
        {
            buffer[i] = copyBuffer[i];
        }
    }

    // 00:0m
    if (strlen(buffer) == 1)
    {
        copyBuffer[0] = '0';
        copyBuffer[1] = '0';
        copyBuffer[2] = '0';
        copyBuffer[3] = buffer[0];

        for (int i = 0; i < size; ++i)
        {
            buffer[i] = copyBuffer[i];
        }
    }

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
    // Получаем время в формате hh:mm 
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
*   Получает собственное серверное время формата HH:MM.
*
*   @param buffer   - буффер для хранения времени.
*   @param size     - размер буффера.
*
*   @return         - ничего не возвращает.
*/
void GetOwnServerTime(char[] buffer, const int size) 
{
    int server_time = GetServerTimeInt();

    // Буффер предназначен для копирования времени из KeyValues файла и сопоставлением с текущим временем сервера, чтобы найти разницу во времени
    int server_time_buffer = TimeToInt(g_sPreferenceServerTime, sizeof(g_sPreferenceServerTime));

    // Храним представление двух временных точек в формате времени
    char buffer_1[8], buffer_2[8], temp[8];

    // Переводим две временные точки в формат hh:mm
    IntToTime(server_time, buffer_1, sizeof(buffer_1));
    IntToTime(server_time_buffer, buffer_2, sizeof(buffer_2));

    // Мы имеем: own_time - последнее сохраненное собственное время, server_time - текущее серверное время, server_time_buffer - последнее сохраненное серверное время
    // Для определения изменения собственного времени, нужно найти разницу между двумя временными точками server_time и server_time_buffer
    // temp - содержит разницу между двумя временными точками delta(t)
    IntToTime(TimeSub(buffer_1, buffer_2), temp, sizeof(temp));

    // Теперь buffer_1 используем для собственного сохраненного времени сервера, а buffer_2 для хранения нового актуального собственного времени сервера
    GetPreferencesValue("own_time", buffer_1, sizeof(buffer_1));
    IntToTime(TimeAdd(buffer_1, temp), buffer_2, sizeof(buffer_2)); 
}

/**
*   Вычитает промежуток времени одной временой точки из другой.
*
*   @param time_1   - первая временная точка.
*   @param time_2   - вторая временная точка.
*
*   @return         - разница во времени (расстояние между двумя временными точками в фомрате времени) представленное в формате Int.
*/
int TimeSub(char[] time_1, char[] time_2)
{
    // Отчищаем две верменные точки от лишних символов 
    ReplaceString(time_1, 8, ":", "");
    ReplaceString(time_1, 8, ":", "");

    // Если формат времени был предоставлен для 00:00, то лучше преобразовать в формат 24:00 
    if (StringToInt(time_2) >= NOON && time_1[0] == '0' && time_1[1] == '0')
    {
        time_1[0] = '2'; time_1[1] = '4';
    }

    // Аналогично для второй временной точки
    if (StringToInt(time_1) >= NOON && time_2[0] == '0' && time_2[1] == '0')
    {
        time_2[0] = '2'; time_2[1] = '4';
    }

    // Непосредственно вычитаем из большей меньшую 
    if (StringToInt(time_1) > StringToInt(time_2))
    {
        return Subtraction(time_1, time_2);
    }
    else 
    {
        return Subtraction(time_2, time_1);
    }
}

/**
*   Складывает промежуток времени одной временой точки из другой.
*
*   @param time_1   - первая временная точка.
*   @param time_2   - вторая временная точка.
*
*   @return         - сумма (расстояние между двумя временными точками в фомрате времени) представленное в формате Int.
*/
int TimeAdd(char[] time_1, char[] time_2)
{
    // Отчищаем две верменные точки от лишних символов 
    ReplaceString(time_1, 8, ":", "");
    ReplaceString(time_1, 8, ":", "");

    return Addition(time_1, time_2);
}

/**
*   Вычитает из одной временной точки - другую
*
*   @param time_1   - первая временная точка (она обязательно должна быть больше второй).
*   @param time_2   - вторая временная точка.
*
*   @return         - разница во времени представленное в формате Int.
*/
int Subtraction(char[] time_1, char[] time_2)
{
    char buffer[8];
    int array[4] = {0, 10, 6, 10};

    for (int i = 3; i > 0; --i)
    {
        if (CharToInt(time_1[i]) - CharToInt(time_2[i]) < 0)
        {
            buffer[i] = IntToChar(CharToInt(time_1[i]) + array[i] - CharToInt(time_2[i]));

            if (CharToInt(time_1[i - 1]) != 0)
            {
                time_1[i - 1] = IntToChar(CharToInt(time_1[i - 1]) - 1);
            }
            else 
            {
                time_1[i - 1] = IntToChar(array[i - 1] - 1);
                time_1[i - 2] = IntToChar(CharToInt(time_1[i - 2]) - 1);
            }
        }
        else 
        {
            buffer[i] = IntToChar(CharToInt(time_1[i]) - CharToInt(time_2[i]));
        }
    }

    buffer[0] = IntToChar(CharToInt(time_1[0]) - CharToInt(time_2[0]));

    return StringToInt(buffer);
}

/**
*   Достает значение из поля Preferences и сохраняет его в буффер.
*
*   @param field        - наименование поля.
*   @param buffer       - буффер для хранения значения.
*   @param size         - размер буффера.
*/
void GetPreferencesValue(const char[] field, char[] buffer, const int size)
{
    KeyValues hPreferences = new KeyValues("Preferences");
	hPreferences.Rewind(); 
	        
    if (hPreferences.ImportFromFile(g_sPathPreferencesKeyValues))
    {
        hPreferences.GetString(field, buffer, size);
    }

    delete hPreferences;
}

/**
*   Обновляет значение поля Preferences.
*
*   @param field        - наименование поля.
*   @param value        - новое значение для поля.
*/
void SetPreferencesValue(const char[] field, char[] value)
{
    KeyValues hPreferences = new KeyValues("Preferences");
	hPreferences.Rewind(); 
	        
    if (hPreferences.ImportFromFile(g_sPathPreferencesKeyValues))
    {
        hPreferences.SetString(field, value);
    }

    delete hPreferences;
}

/**
*   Складывает из одной временной точки - другую.
*
*   @param time_1   - первая временная точка.
*   @param time_2   - вторая временная точка.
*
*   @return         - сумму двух временных точек представленную в формате Int.
*/
int Addition(char[] time_1, char[] time_2)
{
    char buffer[8];
    int array[4] = {0, 10, 6, 10};

    for (int i = 3; i > 0; --i)
    {
        if (CharToInt(time_1[i]) + CharToInt(time_2[i]) >= array[i])
        {
            buffer[i] = IntToChar(CharToInt(time_1[i]) + CharToInt(time_2[i]) - array[i]);
            time_1[i - 1] = IntToChar(CharToInt(time_1[i - 1]) + 1);
        }
        else 
        {
            buffer[i] = IntToChar(CharToInt(time_1[i]) + CharToInt(time_2[i]));
        }
    }

    buffer[0] = IntToChar(CharToInt(time_1[0]) + CharToInt(time_2[0]));

    if (StringToInt(buffer) >= MIDNIGHT)
    {
        IntToTime(Subtraction(buffer, "2400"), buffer, sizeof(buffer));
        ReplaceString(buffer, 8, ":", "");
    }

    return StringToInt(buffer);
}

/**
*   Генерирует плотность тумана, тем самым создает эффект заката и рассвета.
*
*   @return         - ничего не возвращает.
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

/**
*   Конвертируем число типа Int в Char.
*
*   @param time     - число типа Int.
*
*   @return         - символ типа Char или пустой символ, если не смог конвертировать. 
*/
char IntToChar(int number)
{
    // Исправляем ошибку, когда за элемент массива берется несколько чисел типа Int
    int counter = 0, temp = number; 

    while (temp > 0)
    {
        temp /= 10;
        ++counter;
    }

    if (counter > 1)
    {
        number = number / RoundFloat(Pow(float(10), float(counter - 1)));
    }

    // Банальная конвертация из Int в Char
    switch(number)
    {
        case 0: return '0';
        case 1: return '1';
        case 2: return '2';
        case 3: return '3';
        case 4: return '4';
        case 5: return '5';
        case 6: return '6';
        case 7: return '7';
        case 8: return '8';
        case 9: return '9';
    }

    return ' ';
}

/**
*   Конвертируем символ типа Char в Int.
*
*   @param time     - символ типа Char.
*
*   @return         - число типа Int или -1, если не удалось конвертировать.
*/
int CharToInt(char symble)
{
    switch(symble)
    {
        case '0': return 0;
        case '1': return 1;
        case '2': return 2;
        case '3': return 3;
        case '4': return 4;
        case '5': return 5;
        case '6': return 6;
        case '7': return 7;
        case '8': return 8;
        case '9': return 9;
    }

    return -1;
}

/**
*   Обновляет текущие настройки сервера в файл Preferences до актуальных.
*
*   @return     - ничего не возвращает. 
*/
void UpdatePreferences()
{
    KeyValues hPreferences = new KeyValues("Preferences");
	hPreferences.Rewind(); // Preferences
	        
    if (hPreferences.ImportFromFile(g_sPathPreferencesKeyValues))
    {
        char server_time[8], own_time[8];

        GetServerTimeString(server_time, sizeof(server_time));
        GetOwnServerTime(own_time, sizeof(own_time));

        // Сохраняем новые значения серверного времени и собственного
        hPreferences.SetString("own_time", own_time);
        hPreferences.SetString("server_time", server_time);
    }

    delete hPreferences;
}
