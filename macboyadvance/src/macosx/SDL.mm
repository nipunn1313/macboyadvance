/*
 * VisualBoyAdvanced - Nintendo Gameboy/GameboyAdvance (TM) emulator
 * Copyrigh(c) 1999-2002 Forgotten (vb@emuhq.com)
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */
#include <stdarg.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>

#include "AutoBuild.h"

#include "SDL.h"
#include "GBA.h"
#include "agbprint.h"
#include "Flash.h"
#include "Port.h"
#include "debugger.h"
#include "RTC.h"
#include "Sound.h"
#include "Text.h"
#include "unzip.h"
#include "Util.h"
#include "gb/GB.h"
#include "gb/gbGlobals.h"

#ifdef __GNUC__
#include <unistd.h>
#define GETCWD getcwd
#else
#include <direct.h>
#define GETCWD _getcwd
#endif

#include "openfile.h"
#include "MainClass.h"

#define prefs [NSUserDefaults standardUserDefaults]

#ifdef MMX
extern "C" bool cpu_mmx;
#endif
extern bool soundEcho;
extern bool soundLowPass;
extern bool soundReverse;
extern int Init_2xSaI(u32);
extern void _2xSaI(u8*,u32,u8*,u8*,u32,int,int);
extern void _2xSaI32(u8*,u32,u8*,u8*,u32,int,int);  
extern void Super2xSaI(u8*,u32,u8*,u8*,u32,int,int);
extern void Super2xSaI32(u8*,u32,u8*,u8*,u32,int,int);
extern void SuperEagle(u8*,u32,u8*,u8*,u32,int,int);
extern void SuperEagle32(u8*,u32,u8*,u8*,u32,int,int);  
extern void Pixelate(u8*,u32,u8*,u8*,u32,int,int);
extern void Pixelate32(u8*,u32,u8*,u8*,u32,int,int);
extern void MotionBlur(u8*,u32,u8*,u8*,u32,int,int);
extern void MotionBlur32(u8*,u32,u8*,u8*,u32,int,int);
extern void AdMame2x(u8*,u32,u8*,u8*,u32,int,int);
extern void AdMame2x32(u8*,u32,u8*,u8*,u32,int,int);
extern void Simple2x(u8*,u32,u8*,u8*,u32,int,int);
extern void Simple2x32(u8*,u32,u8*,u8*,u32,int,int);
extern void Bilinear(u8*,u32,u8*,u8*,u32,int,int);
extern void Bilinear32(u8*,u32,u8*,u8*,u32,int,int);
extern void BilinearPlus(u8*,u32,u8*,u8*,u32,int,int);
extern void BilinearPlus32(u8*,u32,u8*,u8*,u32,int,int);
extern void Scanlines(u8*,u32,u8*,u8*,u32,int,int);
extern void Scanlines32(u8*,u32,u8*,u8*,u32,int,int);
extern void ScanlinesTV(u8*,u32,u8*,u8*,u32,int,int);
extern void ScanlinesTV32(u8*,u32,u8*,u8*,u32,int,int);
extern void hq2x(u8*,u32,u8*,u8*,u32,int,int);
extern void hq2x32(u8*,u32,u8*,u8*,u32,int,int);
extern void lq2x(u8*,u32,u8*,u8*,u32,int,int);
extern void lq2x32(u8*,u32,u8*,u8*,u32,int,int);

extern void SmartIB(u8*,u32,int,int);
extern void SmartIB32(u8*,u32,int,int);
extern void MotionBlurIB(u8*,u32,int,int);
extern void MotionBlurIB32(u8*,u32,int,int);

void Init_Overlay(SDL_Surface *surface, int overlaytype);
void Quit_Overlay(void);
void Draw_Overlay(SDL_Surface *surface, int size);

extern void debuggerOutput(char *, u32);

extern void CPUUpdateRenderBuffers(bool);

struct EmulatedSystem emulator = {
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  false,
  0
};

int done = 0;
extern int runAgain, cheatCBA, cheatGSA;
extern char launchFile[1024];

SDL_Surface *surface = NULL;
SDL_Overlay *overlay = NULL;
SDL_Rect overlay_rect;

int systemSpeed = 0;
int systemRedShift = 0;
int systemBlueShift = 0;
int systemGreenShift = 0;
int systemColorDepth = 0;
int systemDebug = 0;
int systemVerbose = 0;
int systemFrameSkip = 0;
int systemSaveUpdateCounter = SYSTEM_SAVE_NOT_UPDATED;

int srcPitch = 0;
int srcWidth = 0;
int srcHeight = 0;
int destWidth = 0;
int destHeight = 0;

int sensorX = 2047;
int sensorY = 2047;

int filter = 0;
u8 *delta = NULL;

int cartridgeType = 3;
int sizeOption = 0;
int captureFormat = 0;

int pauseWhenInactive = 0;
int active = 1;
int emulating = 0;
int RGB_LOW_BITS_MASK=0x821;
u32 systemColorMap32[0x10000];
u16 systemColorMap16[0x10000];
u16 systemGbPalette[24];
void (*filterFunction)(u8*,u32,u8*,u8*,u32,int,int) = NULL;
void (*ifbFunction)(u8*,u32,int,int) = NULL;
int ifbType = 0;
char filename[2048];
char ipsname[2048];
char biosFileName[64] = "gbasys.bin";
char captureDir[2048];
char saveDir[2048];
char batteryDir[2048];

#define _stricmp strcasecmp

bool sdlButtons[4][12] = {
  { false, false, false, false, false, false, 
    false, false, false, false, false, false },
  { false, false, false, false, false, false,
    false, false, false, false, false, false },
  { false, false, false, false, false, false,
    false, false, false, false, false, false },
  { false, false, false, false, false, false,
    false, false, false, false, false, false }
};

bool sdlMotionButtons[4] = { false, false, false, false };

int sdlNumDevices = 0;
SDL_Joystick **sdlDevices = NULL;

bool wasPaused = false;
int autoFrameSkip = 0;
int frameskipadjust = 0;
int showRenderedFrames = 0;
int renderedFrames = 0;

int throttle = 0;
u32 throttleLastTime = 0;
u32 autoFrameSkipLastTime = 0;

int showSpeed = 0;
int showSpeedTransparent = 0;
bool disableStatusMessages = false;
bool paused = false;
bool pauseNextFrame = false;
bool debugger = false;
bool debuggerStub = false;
int fullscreen = 0;
bool systemSoundOn = false;
int sdlFlashSize = 0;
int sdlAutoIPS = 1;
int sdlRtcEnable = 0;
int sdlAgbPrint = 0;

int sdlDefaultJoypad = 0;

extern void debuggerSignal(int,int);

void (*dbgMain)() = debuggerMain;
void (*dbgSignal)(int,int) = debuggerSignal;
void (*dbgOutput)(char *, u32) = debuggerOutput;

int  mouseCounter = 0;
int autoFire = 0;
bool autoFireToggle = false;

bool screenMessage = false;
char screenMessageBuffer[21];
u32  screenMessageTime = 0;

SDL_cond *cond = NULL;
SDL_mutex *mutex = NULL;
u8 sdlBuffer[4096];
int sdlSoundLen = 0;

void (*sdlStretcher)(u8 *, u8*) = NULL;

enum {
  KEY_LEFT, KEY_RIGHT,
  KEY_UP, KEY_DOWN,
  KEY_BUTTON_A, KEY_BUTTON_B,
  KEY_BUTTON_START, KEY_BUTTON_SELECT,
  KEY_BUTTON_L, KEY_BUTTON_R,
  KEY_BUTTON_SPEED, KEY_BUTTON_CAPTURE
};

u16 joypad[4][12] = {
  { SDLK_LEFT,  SDLK_RIGHT,
    SDLK_UP,    SDLK_DOWN,
    SDLK_z,     SDLK_x,
    SDLK_RETURN,SDLK_BACKSPACE,
    SDLK_a,     SDLK_s,
    SDLK_SPACE, SDLK_F12
  },
  { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
  { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
  { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
};

u16 defaultJoypad[12] = {
  SDLK_LEFT,  SDLK_RIGHT,
  SDLK_UP,    SDLK_DOWN,
  SDLK_z,     SDLK_x,
  SDLK_RETURN,SDLK_BACKSPACE,
  SDLK_a,     SDLK_s,
  SDLK_SPACE, SDLK_F12
};

u16 motion[4] = {
  SDLK_KP4, SDLK_KP6, SDLK_KP8, SDLK_KP2
};

u16 defaultMotion[4] = {
  SDLK_KP4, SDLK_KP6, SDLK_KP8, SDLK_KP2
};

extern bool CPUIsGBAImage(char *);
extern bool gbIsGameboyRom(char *);

#define SDL_CALL_STRETCHER \
       sdlStretcher(src, dest)

void sdlStretch16x1(u8 *src, u8 *dest)
{
  int width = srcWidth;
  u16 *s = (u16 *)src;
  u16 *d = (u16 *)dest;
  for(int i = 0; i < width; i++)
    *d++ = *s++;
}

void sdlStretch16x2(u8 *src, u8 *dest)
{
  int width = srcWidth;
  u16 *s = (u16 *)src;
  u16 *d = (u16 *)dest;
  for(int i = 0; i < width; i++) {
    *d++ = *s;
    *d++ = *s++;
  }
}

void sdlStretch16x3(u8 *src, u8 *dest)
{
  int width = srcWidth;
  u16 *s = (u16 *)src;
  u16 *d = (u16 *)dest;
  for(int i = 0; i < width; i++) {
    *d++ = *s;
    *d++ = *s;
    *d++ = *s++;
  }
}

void sdlStretch16x4(u8 *src, u8 *dest)
{
  int width = srcWidth;
  u16 *s = (u16 *)src;
  u16 *d = (u16 *)dest;
  for(int i = 0; i < width; i++) {
    *d++ = *s;
    *d++ = *s;
    *d++ = *s;
    *d++ = *s++;
  }
}

void (*sdlStretcher16[4])(u8 *, u8 *) = {
  sdlStretch16x1,
  sdlStretch16x2,
  sdlStretch16x3,
  sdlStretch16x4
};

void sdlStretch32x1(u8 *src, u8 *dest)
{
  int width = srcWidth;
  u32 *s = (u32 *)src;
  u32 *d = (u32 *)dest;
  for(int i = 0; i < width; i++)
    *d++ = *s++;
}

void sdlStretch32x2(u8 *src, u8 *dest)
{
  int width = srcWidth;
  u32 *s = (u32 *)src;
  u32 *d = (u32 *)dest;
  for(int i = 0; i < width; i++) {
    *d++ = *s;
    *d++ = *s++;
  }
}

void sdlStretch32x3(u8 *src, u8 *dest)
{
  int width = srcWidth;
  u32 *s = (u32 *)src;
  u32 *d = (u32 *)dest;
  for(int i = 0; i < width; i++) {
    *d++ = *s;
    *d++ = *s;
    *d++ = *s++;
  }
}

void sdlStretch32x4(u8 *src, u8 *dest)
{
  int width = srcWidth;
  u32 *s = (u32 *)src;
  u32 *d = (u32 *)dest;
  for(int i = 0; i < width; i++) {
    *d++ = *s;
    *d++ = *s;
    *d++ = *s;
    *d++ = *s++;
  }
}

void (*sdlStretcher32[4])(u8 *, u8 *) = {
  sdlStretch32x1,
  sdlStretch32x2,
  sdlStretch32x3,
  sdlStretch32x4
};

void sdlStretch24x1(u8 *src, u8 *dest)
{
  u8 *s = src;
  u8 *d = dest;
  for(int i = 0; i < srcWidth; i++) {
    *d++ = *s++;
    *d++ = *s++;
    *d++ = *s++;
  }
}

void sdlStretch24x2(u8 *src, u8 *dest)
{
  u8 *s = (u8 *)src;
  u8 *d = (u8 *)dest;
  for(int i = 0; i < srcWidth; i++) {
    *d++ = *s;
    *d++ = *(s+1);
    *d++ = *(s+2);
    s += 3;
    *d++ = *s;
    *d++ = *(s+1);
    *d++ = *(s+2);
    s += 3;
  }
}

void sdlStretch24x3(u8 *src, u8 *dest)
{
  u8 *s = (u8 *)src;
  u8 *d = (u8 *)dest;
  for(int i = 0; i < srcWidth; i++) {
    *d++ = *s;
    *d++ = *(s+1);
    *d++ = *(s+2);
    s += 3;
    *d++ = *s;
    *d++ = *(s+1);
    *d++ = *(s+2);
    s += 3;
    *d++ = *s;
    *d++ = *(s+1);
    *d++ = *(s+2);
    s += 3;
  }
}

void sdlStretch24x4(u8 *src, u8 *dest)
{
  u8 *s = (u8 *)src;
  u8 *d = (u8 *)dest;
  for(int i = 0; i < srcWidth; i++) {
    *d++ = *s;
    *d++ = *(s+1);
    *d++ = *(s+2);
    s += 3;
    *d++ = *s;
    *d++ = *(s+1);
    *d++ = *(s+2);
    s += 3;
    *d++ = *s;
    *d++ = *(s+1);
    *d++ = *(s+2);
    s += 3;
    *d++ = *s;
    *d++ = *(s+1);
    *d++ = *(s+2);
    s += 3;
  }
}

void (*sdlStretcher24[4])(u8 *, u8 *) = {
  sdlStretch24x1,
  sdlStretch24x2,
  sdlStretch24x3,
  sdlStretch24x4
};

u32 sdlFromHex(char *s)
{
  u32 value;
  sscanf(s, "%x", &value);
  return value;
}

#ifdef __MSC__
#define stat _stat
#define S_IFDIR _S_IFDIR
#endif

void sdlCheckDirectory(char *dir)
{
  struct stat buf;

  int len = strlen(dir);

  char *p = dir + len - 1;

  if(*p == '/' ||
     *p == '\\')
    *p = 0;
  
  if(stat(dir, &buf) == 0) {
    if(!(buf.st_mode & S_IFDIR)) {
      fprintf(stderr, "Error: %s is not a directory\n", dir);
      dir[0] = 0;
    }
  } else {
    fprintf(stderr, "Error: %s does not exist\n", dir);
    dir[0] = 0;
  }
}

char *sdlGetFilename(char *name)
{
  static char filebuffer[2048];

  int len = strlen(name);
  
  char *p = name + len - 1;
  
  while(true) {
    if(*p == '/' ||
       *p == '\\') {
      p++;
      break;
    }
    len--;
    p--;
    if(len == 0)
      break;
  }
  
  if(len == 0)
    strcpy(filebuffer, name);
  else
    strcpy(filebuffer, p);
  return filebuffer;
}

void sdlReadPreferences(FILE * f)
{
    joypad[0][KEY_LEFT] = [prefs integerForKey:@"Joy0_Left"];
    joypad[0][KEY_RIGHT] = [prefs integerForKey:@"Joy0_Right"];
    joypad[0][KEY_UP] = [prefs integerForKey:@"Joy0_Up"];
    joypad[0][KEY_DOWN] = [prefs integerForKey:@"Joy0_Down"];
    joypad[0][KEY_BUTTON_A] = [prefs integerForKey:@"Joy0_A"];
    joypad[0][KEY_BUTTON_B] = [prefs integerForKey:@"Joy0_B"];
    joypad[0][KEY_BUTTON_L] = [prefs integerForKey:@"Joy0_L"];
    joypad[0][KEY_BUTTON_R] = [prefs integerForKey:@"Joy0_R"];
    joypad[0][KEY_BUTTON_START] = [prefs integerForKey:@"Joy0_Start"];
    joypad[0][KEY_BUTTON_SELECT] = [prefs integerForKey:@"Joy0_Select"];
    joypad[0][KEY_BUTTON_SPEED] = [prefs integerForKey:@"Joy0_Speed"];
    joypad[0][KEY_BUTTON_CAPTURE] = [prefs integerForKey:@"Joy0_Capture"];
    //motion[KEY_LEFT] = [prefs integerForKey:@"Motion_Left"];
    //motion[KEY_RIGHT] = [prefs integerForKey:@"Motion_Right"];
    //motion[KEY_UP] = [prefs integerForKey:@"Motion_Up"];
    //motion[KEY_DOWN] = [prefs integerForKey:@"Motion_Down"];
    frameSkip = [prefs integerForKey:@"frameskip"];
      if(frameSkip < 0 || frameSkip > 9 || frameSkip == 6) {
		gbFrameSkip = frameSkip = 2;
		}
	  else if (frameSkip == 6) {
		autoFrameSkip = 1;
		gbFrameSkip = frameSkip = 0;
		}
    sizeOption = [prefs integerForKey:@"sizeOption"];
      if(sizeOption < 0 || sizeOption > 3)
        sizeOption = 0;
    fullscreen = [prefs integerForKey:@"fullscreen"];
    useBios = [prefs integerForKey:@"useBios"];
    skipBios = [prefs integerForKey:@"skipBios"];
    filter = [prefs integerForKey:@"filter"];
      if(filter < 0 || filter > 13)
        filter = 0;
    gbBorderAutomatic = [prefs integerForKey:@"gbBorder"];
	gbBorderOn = 0;
    gbColorOption = 0;
	strcpy(captureDir, "Screenshots");
	strcpy(saveDir, "Save States");
	strcpy(batteryDir, "Battery Saves");
    soundQuality = [prefs integerForKey:@"soundQuality"];
      switch(soundQuality) {
      case 1:
      case 2:
      case 4:
        break;
      default:
        NSLog(@"Unknown sound quality %d. Defaulting to 22Khz\n", 
                soundQuality);
        soundQuality = 2;
        break;
      }
      soundOffFlag = [prefs integerForKey:@"soundOff"];
      systemSoundOn = !soundOffFlag;
      soundEcho = [prefs integerForKey:@"soundEcho"];
      soundLowPass = [prefs integerForKey:@"soundLowPass"];
      soundReverse = [prefs integerForKey:@"soundReverse"];
      sdlFlashSize = 1;//[prefs integerForKey:@"flashSize"];
      //if(sdlFlashSize != 0 && sdlFlashSize != 1)
      //  sdlFlashSize = 1;
      ifbType = [prefs integerForKey:@"ifbType"];
      if(ifbType < 0 || ifbType > 2)
        ifbType = 0;
      showSpeed = [prefs integerForKey:@"showSpeed"];
      if(showSpeed < 0 || showSpeed > 1)
        showSpeed = 1;
      showSpeedTransparent = showSpeed;
      throttle = [prefs integerForKey:@"throttle"];
      if(throttle != 0 && (throttle < 5 || throttle > 1000))
        throttle = 0;
      pauseWhenInactive = [prefs integerForKey:@"pauseWhenInactive"];
      sdlRtcEnable = [prefs integerForKey:@"rtcEnabled"];
	  alwaysSpeedup = [prefs integerForKey:@"alwaysSpeedup"]; 
	  changeType = [prefs integerForKey:@"changeType"];
}

void sdlSetDefaultPreferences()
{
    [prefs setInteger:0x0114 forKey:@"Joy0_Left"];
    [prefs setInteger:0x0113 forKey:@"Joy0_Right"];
    [prefs setInteger:0x0111 forKey:@"Joy0_Up"];
    [prefs setInteger:0x0112 forKey:@"Joy0_Down"];
    [prefs setInteger:0x007a forKey:@"Joy0_A"];
    [prefs setInteger:0x0078 forKey:@"Joy0_B"];
    [prefs setInteger:0x0061 forKey:@"Joy0_L"];
    [prefs setInteger:0x0073 forKey:@"Joy0_R"];
    [prefs setInteger:0x000d forKey:@"Joy0_Start"];
    [prefs setInteger:0x0008 forKey:@"Joy0_Select"];
    [prefs setInteger:0x0020 forKey:@"Joy0_Speed"];
    [prefs setInteger:0x003d forKey:@"Joy0_Capture"];
    [prefs setInteger:2 forKey:@"frameskip"];
    [prefs setInteger:0 forKey:@"sizeOption"];
    [prefs setInteger:0 forKey:@"fullscreen"];
    [prefs setInteger:0 forKey:@"useBios"];
    [prefs setInteger:0 forKey:@"skipBios"];
    [prefs setInteger:0 forKey:@"filter"];
    [prefs setInteger:1 forKey:@"gbBorder"];
    [prefs setInteger:2 forKey:@"soundQuality"];
    [prefs setInteger:0 forKey:@"soundOff"];
    [prefs setInteger:0 forKey:@"soundEcho"];
    [prefs setInteger:0 forKey:@"soundLowPass"];
    [prefs setInteger:0 forKey:@"soundReverse"];
    //[prefs setInteger:1 forKey:@"flashSize"];
    [prefs setInteger:0 forKey:@"ifbType"];
    [prefs setInteger:0 forKey:@"showSpeed"];
    [prefs setInteger:0 forKey:@"throttle"];
    [prefs setInteger:0 forKey:@"pauseWhenInactive"];
    [prefs setInteger:0 forKey:@"rtcEnabled"];
    [prefs setInteger:1 forKey:@"changeType"];
	[prefs setInteger:0	forKey:@"alwaysSpeedup"];
}

void sdlReadPreferences()
{
    if([prefs integerForKey:@"Version"] != 174)
        {
            [prefs setInteger:174 forKey:@"Version"];
            //set all defaults
            sdlSetDefaultPreferences();
        }

    sdlReadPreferences(NULL);
}

static int sdlCalculateShift(u32 mask)
{
  int m = 0;
  
  while(mask) {
    m++;
    mask >>= 1;
  }

  return m-5;
}

static int sdlCalculateMaskWidth(u32 mask)
{
  int m = 0;
  int mask2 = mask;

  while(mask2) {
    m++;
    mask2 >>= 1;
  }

  int m2 = 0;
  mask2 = mask;
  while(!(mask2 & 1)) {
    m2++;
    mask2 >>= 1;
  }

  return m - m2;
}

void sdlWriteState(int num)
{
  char stateName[2048];

  if(saveDir[0])
    sprintf(stateName, "%s/%s%d.sgm", saveDir, sdlGetFilename(filename),
            num+1);
  else
    sprintf(stateName,"%s%d.sgm", filename, num+1);
  if(emulator.emuWriteState)
    emulator.emuWriteState(stateName);
  sprintf(stateName, "Wrote state %d", num+1);
  systemScreenMessage(stateName);
}

void sdlReadState(int num)
{
  char stateName[2048];

  if(saveDir[0])
    sprintf(stateName, "%s/%s%d.sgm", saveDir, sdlGetFilename(filename),
            num+1);
  else
    sprintf(stateName,"%s%d.sgm", filename, num+1);

  if(emulator.emuReadState)
    emulator.emuReadState(stateName);

  sprintf(stateName, "Loaded state %d", num+1);
  systemScreenMessage(stateName);
}

void sdlWriteBattery()
{
  char buffer[1048];

  if(batteryDir[0])
    sprintf(buffer, "%s/%s.sav", batteryDir, sdlGetFilename(filename));
  else  
    sprintf(buffer, "%s.sav", filename);

  emulator.emuWriteBattery(buffer);

  systemScreenMessage("Wrote battery");
  [gSDLMain changeSaveCreator:buffer];
}

void sdlReadBattery()
{
  char buffer[1048];
  
  if(batteryDir[0])
    sprintf(buffer, "%s/%s.sav", batteryDir, sdlGetFilename(filename));
  else 
    sprintf(buffer, "%s.sav", filename);
  
  bool res = false;

  res = emulator.emuReadBattery(buffer);

  if(res)
    systemScreenMessage("Loaded battery");
}

#define MOD_KEYS    (KMOD_CTRL|KMOD_SHIFT|KMOD_ALT|KMOD_META)
#define MOD_NOCTRL  (KMOD_SHIFT|KMOD_ALT|KMOD_META)
#define MOD_NOALT   (KMOD_CTRL|KMOD_SHIFT|KMOD_META)
#define MOD_NOSHIFT (KMOD_CTRL|KMOD_ALT|KMOD_META)

void sdlUpdateKey(int key, bool down)
{
  int i;
  for(int j = 0; j < 4; j++) {
    for(i = 0 ; i < 12; i++) {
      if((joypad[j][i] & 0xf000) == 0) {
        if(key == joypad[j][i])
          sdlButtons[j][i] = down;
      }
    }
  }
  for(i = 0 ; i < 4; i++) {
    if((motion[i] & 0xf000) == 0) {
      if(key == motion[i])
        sdlMotionButtons[i] = down;
    }
  }
}

void sdlUpdateJoyButton(int which,
                        int button,
                        bool pressed)
{
  int i;
  for(int j = 0; j < 4; j++) {
    for(i = 0; i < 12; i++) {
      int dev = (joypad[j][i] >> 12);
      int b = joypad[j][i] & 0xfff;
      if(dev) {
        dev--;
        
        if((dev == which) && (b >= 128) && (b == (button+128))) {
          sdlButtons[j][i] = pressed;
        }
      }
    }
  }
  for(i = 0; i < 4; i++) {
    int dev = (motion[i] >> 12);
    int b = motion[i] & 0xfff;
    if(dev) {
      dev--;

      if((dev == which) && (b >= 128) && (b == (button+128))) {
        sdlMotionButtons[i] = pressed;
      }
    }
  }  
}

void sdlUpdateJoyHat(int which,
                     int hat,
                     int value)
{
  int i;
  for(int j = 0; j < 4; j++) {
    for(i = 0; i < 12; i++) {
      int dev = (joypad[j][i] >> 12);
      int a = joypad[j][i] & 0xfff;
      if(dev) {
        dev--;
        
        if((dev == which) && (a>=32) && (a < 48) && (((a&15)>>2) == hat)) {
          int dir = a & 3;
          int v = 0;
          switch(dir) {
          case 0:
            v = value & SDL_HAT_UP;
            break;
          case 1:
            v = value & SDL_HAT_DOWN;
            break;
          case 2:
            v = value & SDL_HAT_RIGHT;
            break;
          case 3:
            v = value & SDL_HAT_LEFT;
            break;
          }
          sdlButtons[j][i] = (v ? true : false);
        }
      }
    }
  }
  for(i = 0; i < 4; i++) {
    int dev = (motion[i] >> 12);
    int a = motion[i] & 0xfff;
    if(dev) {
      dev--;

      if((dev == which) && (a>=32) && (a < 48) && (((a&15)>>2) == hat)) {
        int dir = a & 3;
        int v = 0;
        switch(dir) {
        case 0:
          v = value & SDL_HAT_UP;
          break;
        case 1:
          v = value & SDL_HAT_DOWN;
          break;
        case 2:
          v = value & SDL_HAT_RIGHT;
          break;
        case 3:
          v = value & SDL_HAT_LEFT;
          break;
        }
        sdlMotionButtons[i] = (v ? true : false);
      }
    }
  }      
}

void sdlUpdateJoyAxis(int which,
                      int axis,
                      int value)
{
  int i;
  for(int j = 0; j < 4; j++) {
    for(i = 0; i < 12; i++) {
      int dev = (joypad[j][i] >> 12);
      int a = joypad[j][i] & 0xfff;
      if(dev) {
        dev--;
        
        if((dev == which) && (a < 32) && ((a>>1) == axis)) {
          sdlButtons[j][i] = (a & 1) ? (value > 16384) : (value < -16384);
        }
      }
    }
  }
  for(i = 0; i < 4; i++) {
    int dev = (motion[i] >> 12);
    int a = motion[i] & 0xfff;
    if(dev) {
      dev--;

      if((dev == which) && (a < 32) && ((a>>1) == axis)) {
        sdlMotionButtons[i] = (a & 1) ? (value > 16384) : (value < -16384);
      }
    }
  }  
}

bool sdlCheckJoyKey(int key)
{
  int dev = (key >> 12) - 1;
  int what = key & 0xfff;

  if(what >= 128) {
    // joystick button
    int button = what - 128;

    if(button >= SDL_JoystickNumButtons(sdlDevices[dev]))
      return false;
  } else if (what < 0x20) {
    // joystick axis    
    what >>= 1;
    if(what >= SDL_JoystickNumAxes(sdlDevices[dev]))
      return false;
  } else if (what < 0x30) {
    // joystick hat
    what = (what & 15);
    what >>= 2;
    if(what >= SDL_JoystickNumHats(sdlDevices[dev]))
      return false;
  }

  // no problem found
  return true;
}

void sdlCheckKeys()
{
  sdlNumDevices = SDL_NumJoysticks();

  if(sdlNumDevices)
    sdlDevices = (SDL_Joystick **)calloc(1,sdlNumDevices *
                                         sizeof(SDL_Joystick **));
  int i;

  bool usesJoy = false;

  for(int j = 0; j < 4; j++) {
    for(i = 0; i < 12; i++) {
      int dev = joypad[j][i] >> 12;
      if(dev) {
        dev--;
        bool ok = false;
        
        if(sdlDevices) {
          if(dev < sdlNumDevices) {
            if(sdlDevices[dev] == NULL) {
              sdlDevices[dev] = SDL_JoystickOpen(dev);
            }
            
            ok = sdlCheckJoyKey(joypad[j][i]);
          } else
            ok = false;
        }
        
        if(!ok)
          joypad[j][i] = defaultJoypad[i];
        else
          usesJoy = true;
      }
    }
  }

  for(i = 0; i < 4; i++) {
    int dev = motion[i] >> 12;
    if(dev) {
      dev--;
      bool ok = false;
      
      if(sdlDevices) {
        if(dev < sdlNumDevices) {
          if(sdlDevices[dev] == NULL) {
            sdlDevices[dev] = SDL_JoystickOpen(dev);
          }
          
          ok = sdlCheckJoyKey(motion[i]);
        } else
          ok = false;
      }
      
      if(!ok)
        motion[i] = defaultMotion[i];
      else
        usesJoy = true;
    }
  }

  if(usesJoy)
    SDL_JoystickEventState(SDL_ENABLE);
}

void sdlEmuPause()
{
    paused = !paused;
    SDL_PauseAudio(paused);
    if(paused)
        wasPaused = true;
}

void sdlEmuReset()
{
    if(emulating) {
        emulator.emuReset();
        systemScreenMessage("Reset");
        }
}

void sdlPollEvents()
{
  SDL_Event event;
  while(SDL_PollEvent(&event)) {
    switch(event.type) {
	case SDL_QUIT:
		emulating = 0;
		break;
    case SDL_ACTIVEEVENT:
      if(pauseWhenInactive && (event.active.state & SDL_APPINPUTFOCUS)) {
        active = event.active.gain;
        if(active) {
          if(!paused) {
            if(emulating)
              soundResume();
          }
        } else {
          wasPaused = true;
          if(pauseWhenInactive) {
            if(emulating)
              soundPause();
          }
          
          memset(delta,255,sizeof(delta));
        }
      }
      break;
    case SDL_JOYHATMOTION:
      sdlUpdateJoyHat(event.jhat.which,
                      event.jhat.hat,
                      event.jhat.value);
      break;
    case SDL_JOYBUTTONDOWN:
    case SDL_JOYBUTTONUP:
      sdlUpdateJoyButton(event.jbutton.which,
                         event.jbutton.button,
                         event.jbutton.state == SDL_PRESSED);
      break;
    case SDL_JOYAXISMOTION:
      sdlUpdateJoyAxis(event.jaxis.which,
                       event.jaxis.axis,
                       event.jaxis.value);
      break;
    case SDL_KEYDOWN:
      sdlUpdateKey(event.key.keysym.sym, true);
      break;
    case SDL_KEYUP:
      switch(event.key.keysym.sym) {
      case SDLK_r:
        if(event.key.keysym.mod & KMOD_META) {
          if(emulating) {
            emulator.emuReset();

            systemScreenMessage("Reset");
          }
        }
        break;
		case SDLK_p:
        if(event.key.keysym.mod & KMOD_META) {
          paused = !paused;
          SDL_PauseAudio(paused);
          if(paused)
            wasPaused = true;
        }
        break;
      case SDLK_q:
        if(event.key.keysym.mod & KMOD_META) {
            done = 1;
            emulating = 0;
        }
        break;
      case SDLK_f:
        if(event.key.keysym.mod & KMOD_META) {
           sdlWriteState(0);
        }
        break;
      case SDLK_d:
        if(event.key.keysym.mod & KMOD_META) {
           sdlReadState(0);
        }
        break;
      case SDLK_o:
        if(event.key.keysym.mod & KMOD_META) {
           emulating = 0;
           runAgain = 1;
        }
        break;
      case SDLK_w:
        if(event.key.keysym.mod & KMOD_META) {
           emulating = 0;
        }
        break;
      case SDLK_ESCAPE:
          {
            int flags = 0;
            fullscreen = !fullscreen;
            SDL_ShowCursor(!fullscreen);
            if(fullscreen)
                flags |= SDL_FULLSCREEN|SDL_SWSURFACE;
            else
                flags |= SDL_SWSURFACE;
            SDL_SetVideoMode(destWidth, destHeight, systemColorDepth, flags);
          }
        break;
      case SDLK_F1:
      case SDLK_F2:
      case SDLK_F3:
      case SDLK_F4:
      case SDLK_F5:
      case SDLK_F6:
      case SDLK_F7:
      case SDLK_F8:
        if(!(event.key.keysym.mod & MOD_NOSHIFT) &&
           (event.key.keysym.mod & KMOD_SHIFT)) {
          sdlWriteState(event.key.keysym.sym-SDLK_F1);
        } else if(!(event.key.keysym.mod & MOD_KEYS)) {
          sdlReadState(event.key.keysym.sym-SDLK_F1);
        }
        break;
      case SDLK_1:
      case SDLK_2:
      case SDLK_3:
      case SDLK_4:
        if(!(event.key.keysym.mod & MOD_NOALT) &&
           (event.key.keysym.mod & KMOD_ALT)) {
          char *disableMessages[4] = 
            { "autofire A disabled",
              "autofire B disabled",
              "autofire R disabled",
              "autofire L disabled"};
          char *enableMessages[4] = 
            { "autofire A",
              "autofire B",
              "autofire R",
              "autofire L"};
          int mask = 1 << (event.key.keysym.sym - SDLK_1);
    if(event.key.keysym.sym > SDLK_2)
      mask <<= 6;
          if(autoFire & mask) {
            autoFire &= ~mask;
            systemScreenMessage(disableMessages[event.key.keysym.sym - SDLK_1]);
          } else {
            autoFire |= mask;
            systemScreenMessage(enableMessages[event.key.keysym.sym - SDLK_1]);
          }
        } if(!(event.key.keysym.mod & MOD_NOCTRL) &&
             (event.key.keysym.mod & KMOD_CTRL)) {
          int mask = 0x0100 << (event.key.keysym.sym - SDLK_1);
          layerSettings ^= mask;
          layerEnable = DISPCNT & layerSettings;
          CPUUpdateRenderBuffers(false);
        }
        break;
      case SDLK_5:
      case SDLK_6:
      case SDLK_7:
      case SDLK_8:
        if(!(event.key.keysym.mod & MOD_NOCTRL) &&
           (event.key.keysym.mod & KMOD_CTRL)) {
          int mask = 0x0100 << (event.key.keysym.sym - SDLK_1);
          layerSettings ^= mask;
          layerEnable = DISPCNT & layerSettings;
        }
        break;
      case SDLK_n:
        if(!(event.key.keysym.mod & MOD_NOCTRL) &&
           (event.key.keysym.mod & KMOD_CTRL)) {
          if(paused)
            paused = false;
          pauseNextFrame = true;
        }
        break;
      default:
        break;
      }
      sdlUpdateKey(event.key.keysym.sym, false);
      break;
    }
  }
}

int main(int argc, char **argv)
{
  bool failed = false;
  
  char szFile[1024];
  captureDir[0] = 0;
  saveDir[0] = 0;
  batteryDir[0] = 0;
  ipsname[0] = 0;

  frameSkip = 2;
  gbBorderOn = 0;
	
  sdlReadPreferences();
	
  if(sdlFlashSize == 0)
    flashSetSize(0x10000);
  else
    flashSetSize(0x20000);

  rtcEnable(sdlRtcEnable ? true : false);
  agbPrintEnable(sdlAgbPrint ? true : false);

  if(filter) {
    sizeOption = 1;
  }

  for(int i = 0; i < 24;) {
    systemGbPalette[i++] = (0x1f) | (0x1f << 5) | (0x1f << 10);
    systemGbPalette[i++] = (0x15) | (0x15 << 5) | (0x15 << 10);
    systemGbPalette[i++] = (0x0c) | (0x0c << 5) | (0x0c << 10);
    systemGbPalette[i++] = 0;
  }

  systemSaveUpdateCounter = SYSTEM_SAVE_NOT_UPDATED;
  
  szFile[0] = '\0';
  
  if (launchFile[0] != '\0')
    strcpy(szFile, launchFile);
  else
    openFile(szFile);
  
  if(szFile[0] != '\0')
  {
    
    if (changeType)
        [gSDLMain changeCreator:szFile];
    strcpy(filename, szFile);
    char *p = strrchr(filename, '.');

    if(p)
      *p = 0;

    if(ipsname[0] == 0)
      sprintf(ipsname, "%s.ips", filename);

    IMAGE_TYPE type = utilFindType(szFile);

    if(type == IMAGE_UNKNOWN) {
      systemMessage(0, "Unknown file type %s", szFile);
      exit(-1);
    }
    cartridgeType = (int)type;
    
    if(type == IMAGE_GB) {
      failed = !gbLoadRom(szFile);
      if(!failed) {
        cartridgeType = 1;
        emulator = GBSystem;
        if(sdlAutoIPS) {
          int size = gbRomSize;
          utilApplyIPS(ipsname, &gbRom, &size);
          if(size != gbRomSize) {
            extern bool gbUpdateSizes();
            gbUpdateSizes();
            gbReset();
          }
        }
      }
    } else if(type == IMAGE_GBA) {
      int size = CPULoadRom(szFile);
      failed = (size == 0);
      if(!failed) {
        //if(cpuEnhancedDetection && cpuSaveType == 0) {
        //utilGBAFindSave(rom, size);
        //}
        
        cartridgeType = 0;
        emulator = GBASystem;
        
        CPUInit(biosFileName, useBios);
        CPUReset();
        if(sdlAutoIPS) {
          int size = 0x2000000;
          utilApplyIPS(ipsname, &rom, &size);
          if(size != 0x2000000) {
            CPUReset();
          }
        }
      }
    }
    
    if(failed) {
      systemMessage(0, "Failed to load file %s", szFile);
      return 0;
    }
  } else {
    return 0;   
  }
  
  sdlReadBattery();
  
  if (cheatCBA == 1 && cartridgeType == 0)
    {
    [gSDLMain addCheatCBA];
    cheatCBA = 0;
    }
    
  if (cheatGSA == 1 && cartridgeType == 0)
    {
    [gSDLMain addCheatGSA];
    cheatGSA = 0;
    }
    
  int flags = SDL_INIT_VIDEO|SDL_INIT_AUDIO|
    SDL_INIT_TIMER|SDL_INIT_NOPARACHUTE;

  if(soundOffFlag)
    flags ^= SDL_INIT_AUDIO;
  
  if(SDL_Init(flags)) {
    systemMessage(0, "Failed to init SDL: %s", SDL_GetError());
    exit(-1);
  }

  if(SDL_InitSubSystem(SDL_INIT_JOYSTICK)) {
    systemMessage(0, "Failed to init joystick support: %s", SDL_GetError());
  }
  
  sdlCheckKeys();
  
  if(cartridgeType == 0) {
    srcWidth = 240;
    srcHeight = 160;
    systemFrameSkip = frameSkip;
  } else if (cartridgeType == 1) {
    if(gbBorderOn) {
      srcWidth = 256;
      srcHeight = 224;
      gbBorderLineSkip = 256;
      gbBorderColumnSkip = 48;
      gbBorderRowSkip = 40;
    } else {      
      srcWidth = 160;
      srcHeight = 144;
      gbBorderLineSkip = 160;
      gbBorderColumnSkip = 0;
      gbBorderRowSkip = 0;
    }
    systemFrameSkip = gbFrameSkip;
  } else {
    srcWidth = 320;
    srcHeight = 240;
  }
  
  destWidth = (sizeOption+1)*srcWidth;
  destHeight = (sizeOption+1)*srcHeight;
  
  //surface = SDL_SetVideoMode(destWidth, destHeight, 0, SDL_SWSURFACE | (fullscreen ? SDL_FULLSCREEN : 0));
  surface = SDL_SetVideoMode(destWidth, destHeight, 0, SDL_SWSURFACE);
  
  if(surface == NULL) {
    systemMessage(0, "Failed to set video mode");
    SDL_Quit();
    return 0;
  }
  
  systemRedShift = sdlCalculateShift(surface->format->Rmask);
  systemGreenShift = sdlCalculateShift(surface->format->Gmask);
  systemBlueShift = sdlCalculateShift(surface->format->Bmask);
  
  systemColorDepth = surface->format->BitsPerPixel;
  if(systemColorDepth == 15)
    systemColorDepth = 16;
  
  if(systemColorDepth != 16 && systemColorDepth != 24 &&
     systemColorDepth != 32) {
    systemMessage(0,"Unsupported color depth '%d'.\nOnly 16, 24 and 32 bit color depths are supported\n", systemColorDepth);
	SDL_Quit();
	return 0;
  }
  
  SDL_SetVideoMode(destWidth, destHeight, 0, SDL_SWSURFACE | (fullscreen ? SDL_FULLSCREEN : 0));
   
   if(surface == NULL) {
    systemMessage(0, "Failed to set video mode");
    SDL_Quit();
    return 0;
  }
   
   SDL_ShowCursor(!fullscreen);

  switch(systemColorDepth) {
  case 16:
    sdlStretcher = sdlStretcher16[sizeOption];
    break;
  case 24:
    sdlStretcher = sdlStretcher24[sizeOption];
    break;
  case 32:
    sdlStretcher = sdlStretcher32[sizeOption];
    break;
  default:
    fprintf(stderr, "Unsupported resolution: %d\n", systemColorDepth);
    exit(-1);
  }

  //fprintf(stderr,"Color depth: %d\n", systemColorDepth);
  
  if(systemColorDepth == 16) {
    if(sdlCalculateMaskWidth(surface->format->Gmask) == 6) {
      Init_2xSaI(565);
      RGB_LOW_BITS_MASK = 0x821;
    } else {
      Init_2xSaI(555);
      RGB_LOW_BITS_MASK = 0x421;      
    }
    if(cartridgeType == 2) {
      for(int i = 0; i < 0x10000; i++) {
        systemColorMap16[i] = (((i >> 1) & 0x1f) << systemBlueShift) |
          (((i & 0x7c0) >> 6) << systemGreenShift) |
          (((i & 0xf800) >> 11) << systemRedShift);  
      }      
    } else {
	  for(int i = 0; i < 0x10000; i++) {
        systemColorMap16[i] = ((i & 0x1f) << systemRedShift) |
          (((i & 0x3e0) >> 5) << systemGreenShift) |
          (((i & 0x7c00) >> 10) << systemBlueShift);  
      }
    }
    srcPitch = srcWidth * 2+4;
  } else {
    if(systemColorDepth != 32)
      filterFunction = NULL;
    RGB_LOW_BITS_MASK = 0x010101;
    if(systemColorDepth == 32) {
      Init_2xSaI(32);
    }
    for(int i = 0; i < 0x10000; i++) {
      systemColorMap32[i] = ((i & 0x1f) << systemRedShift) |
        (((i & 0x3e0) >> 5) << systemGreenShift) |
        (((i & 0x7c00) >> 10) << systemBlueShift);  
    }
    if(systemColorDepth == 32)
      srcPitch = srcWidth*4 + 4;
    else
      srcPitch = srcWidth*3;
  }

  if(systemColorDepth != 32) {
    switch(filter) {
    case 0:
      filterFunction = NULL;
      break;
    case 1:
      filterFunction = ScanlinesTV;
      break;
    case 2:
      filterFunction = _2xSaI;
      break;
    case 3:
      filterFunction = Super2xSaI;
      break;
    case 4:
      filterFunction = SuperEagle;
      break;
    case 5:
      filterFunction = Pixelate;
      break;
    case 6:
      filterFunction = MotionBlur;
      break;
    case 7:
      filterFunction = AdMame2x;
      break;
    case 8:
      filterFunction = Simple2x;
      break;
    case 9:
      filterFunction = Bilinear;
      break;
    case 10:
      filterFunction = BilinearPlus;
      break;
    case 11:
      filterFunction = Scanlines;
      break;
    case 12:
      filterFunction = hq2x;
      break;
    case 13:
      filterFunction = lq2x;
      break;
    default:
      filterFunction = NULL;
      break;
    }
  } else {
    switch(filter) {
    case 0:
      filterFunction = NULL;
      break;
    case 1:
      filterFunction = ScanlinesTV32;
      break;
    case 2:
      filterFunction = _2xSaI32;
      break;
    case 3:
      filterFunction = Super2xSaI32;
      break;
    case 4:
      filterFunction = SuperEagle32;
      break;
    case 5:
      filterFunction = Pixelate32;
      break;
    case 6:
      filterFunction = MotionBlur32;
      break;
    case 7:
      filterFunction = AdMame2x32;
      break;
    case 8:
      filterFunction = Simple2x32;
      break;
    case 9:
      filterFunction = Bilinear32;
      break;
    case 10:
      filterFunction = BilinearPlus32;
      break;
    case 11:
      filterFunction = Scanlines32;
      break;
    case 12:
      filterFunction = hq2x32;
      break;
    case 13:
      filterFunction = lq2x32;
      break;
    default:
      filterFunction = NULL;
      break;
    }
  }
  
  if(systemColorDepth == 16) {
    switch(ifbType) {
    case 0:
    default:
      ifbFunction = NULL;
      break;
    case 1:
      ifbFunction = MotionBlurIB;
      break;
    case 2:
      ifbFunction = SmartIB;
      break;
    }
  } else if(systemColorDepth == 32) {
    switch(ifbType) {
    case 0:
    default:
      ifbFunction = NULL;
      break;
    case 1:
      ifbFunction = MotionBlurIB32;
      break;
    case 2:
      ifbFunction = SmartIB32;
      break;
    }
  } else
    ifbFunction = NULL;

  if(delta == NULL) {
    delta = (u8*)malloc(322*242*4);
    memset(delta, 255, 322*242*4);
  }
  
  emulating = 1;
  renderedFrames = 0;

  if(!soundOffFlag)
    soundInit();

  autoFrameSkipLastTime = throttleLastTime = systemGetClock();
    
  SDL_WM_SetCaption("VBA", NULL);
  
  while(emulating) {
    sdlPollEvents();
    if(!paused && active)
	  emulator.emuMain(emulator.emuCount);
	else
      SDL_Delay(500);
	}
  
  emulating = 0;
  //fprintf(stderr,"Shutting down\n");
  soundShutdown();

  if(gbRom != NULL || rom != NULL) {
    sdlWriteBattery();
    emulator.emuCleanUp();
  }

  if(delta) {
    free(delta);
    delta = NULL;
  }
  SDL_Quit();
  return 0;
}

void systemMessage(int num, const char *msg, ...)
{
  char buffer[2048];
  va_list valist;
  
  va_start(valist, msg);
  vsprintf(buffer, msg, valist);
  
  NSString * string = [[NSString alloc] initWithCString:buffer];
  NSRunInformationalAlertPanel(@"Error!", string ,@"OK",NULL,NULL);
  va_end(valist);
}

void systemDrawScreen()
{
  renderedFrames++;
  int pitch = srcPitch;
  SDL_LockSurface(surface);

  if(screenMessage) {
    if(cartridgeType == 1 && gbBorderOn) {
      gbSgbRenderBorder();
    }
    if(((systemGetClock() - screenMessageTime) < 3000) &&
       !disableStatusMessages) {
      drawText(pix, pitch, 10, srcHeight - 20,
               screenMessageBuffer); 
    } else {
      screenMessage = false;
    }
  }

  if(ifbFunction) {
    if(systemColorDepth == 16)
      ifbFunction(pix+destWidth+4, destWidth+4, srcWidth, srcHeight);
    else
      ifbFunction(pix+destWidth*2+4, destWidth*2+4, srcWidth, srcHeight);
  }
  
  if(filterFunction) {
    if(systemColorDepth == 16)
      filterFunction(pix+destWidth+4,destWidth+4, delta,
                     (u8*)surface->pixels,surface->pitch,
                     srcWidth,
                     srcHeight);
    else
      filterFunction(pix+destWidth*2+4,
                     destWidth*2+4,
                     delta,
                     (u8*)surface->pixels,
                     surface->pitch,
                     srcWidth,
                     srcHeight);
  } else {
    int destPitch = surface->pitch;
    u8 *src = pix;
    u8 *dest = (u8*)surface->pixels;
    int i;
    if(systemColorDepth == 16)
      src += pitch;
    int option = sizeOption;
    int height = srcHeight;
    switch(option) {
    case 0:
      for(i = 0; i < height; i++) {
        SDL_CALL_STRETCHER;
        src += pitch;
        dest += destPitch;
      }
      break;
    case 1:
      for(i = 0; i < height; i++) {
        SDL_CALL_STRETCHER;     
        dest += destPitch;
        SDL_CALL_STRETCHER;
        src += pitch;
        dest += destPitch;
      }
      break;
    case 2:
      for(i = 0; i < height; i++) {
        SDL_CALL_STRETCHER;
        dest += destPitch;
        SDL_CALL_STRETCHER;
        dest += destPitch;
        SDL_CALL_STRETCHER;
        src += pitch;
        dest += destPitch;
      }
      break;
    case 3:
      for(i = 0; i < height; i++) {
        SDL_CALL_STRETCHER;
        dest += destPitch;
        SDL_CALL_STRETCHER;
        dest += destPitch;
        SDL_CALL_STRETCHER;
        dest += destPitch;
        SDL_CALL_STRETCHER;
        src += pitch;
        dest += destPitch;
      }
      break;
    }
  }

  if(showSpeed && fullscreen) {
    char buffer[50];
    if(showSpeed == 1)
      sprintf(buffer, "%d%%", systemSpeed);
    else
      sprintf(buffer, "%3d%%(%d, %d fps)", systemSpeed,
              systemFrameSkip,
              showRenderedFrames);
    if(showSpeedTransparent)
      drawTextTransp((u8*)surface->pixels,
                     surface->pitch,
                     10,
                     surface->h-20,
                     buffer);
    else
      drawText((u8*)surface->pixels,
               surface->pitch,
               10,
               surface->h-20,
               buffer);        
  }  

  SDL_UnlockSurface(surface);
  SDL_Flip(surface);
}

bool systemReadJoypads()
{
  return true;
}

u32 systemReadJoypad(int which)
{
  if(which < 0 || which > 3)
    which = sdlDefaultJoypad;
  
  u32 res = 0;
  
  if(sdlButtons[which][KEY_BUTTON_A])
    res |= 1;
  if(sdlButtons[which][KEY_BUTTON_B])
    res |= 2;
  if(sdlButtons[which][KEY_BUTTON_SELECT])
    res |= 4;
  if(sdlButtons[which][KEY_BUTTON_START])
    res |= 8;
  if(sdlButtons[which][KEY_RIGHT])
    res |= 16;
  if(sdlButtons[which][KEY_LEFT])
    res |= 32;
  if(sdlButtons[which][KEY_UP])
    res |= 64;
  if(sdlButtons[which][KEY_DOWN])
    res |= 128;
  if(sdlButtons[which][KEY_BUTTON_R])
    res |= 256;
  if(sdlButtons[which][KEY_BUTTON_L])
    res |= 512;

  // disallow L+R or U+D of being pressed at the same time
  if((res & 48) == 48)
    res &= ~16;
  if((res & 192) == 192)
    res &= ~128;

  if(sdlButtons[which][KEY_BUTTON_SPEED])
    res |= 1024;
  if(sdlButtons[which][KEY_BUTTON_CAPTURE])
    res |= 2048;

  if(autoFire) {
    res &= (~autoFire);
    if(autoFireToggle)
      res |= autoFire;
    autoFireToggle = !autoFireToggle;
  }
  
  return res;
}

void systemSetTitle(const char *title)
{
  SDL_WM_SetCaption(title, NULL);
}

void systemShowSpeed(int speed)
{
  systemSpeed = speed;

  showRenderedFrames = renderedFrames;
  renderedFrames = 0;  

  if(!fullscreen && showSpeed) {
    char buffer[80];
    if(showSpeed == 1)
      sprintf(buffer, "VBA-%3d%%", systemSpeed);
    else
      sprintf(buffer, "VBA-%3d%%(%d, %d fps)", systemSpeed,
              systemFrameSkip,
              showRenderedFrames);

    systemSetTitle(buffer);
  }
}

void systemFrame()
{
}

void system10Frames(int rate)
{
  u32 time = systemGetClock();  
  if(!wasPaused && autoFrameSkip && !throttle) {
    u32 diff = time - autoFrameSkipLastTime;
    int speed = 100;

    if(diff)
      speed = (1000000/rate)/diff;
    
    if(speed >= 98) {
      frameskipadjust++;

      if(frameskipadjust >= 3) {
        frameskipadjust=0;
        if(systemFrameSkip > 0)
          systemFrameSkip--;
      }
    } else {
      if(speed  < 80)
        frameskipadjust -= (90 - speed)/5;
      else if(systemFrameSkip < 9)
        frameskipadjust--;

      if(frameskipadjust <= -2) {
        frameskipadjust += 2;
        if(systemFrameSkip < 9)
          systemFrameSkip++;
      }
    }    
  }
  if(!wasPaused && throttle) {
    if(!speedup) {
      u32 diff = time - throttleLastTime;
      
      int target = (1000000/(rate*throttle));
      int d = (target - diff);
      
      if(d > 0) {
        SDL_Delay(d);
      }
    }
    throttleLastTime = systemGetClock();
  }
  
  if(systemSaveUpdateCounter) {
    if(--systemSaveUpdateCounter <= SYSTEM_SAVE_NOT_UPDATED) {
      sdlWriteBattery();
      systemSaveUpdateCounter = SYSTEM_SAVE_NOT_UPDATED;
    }
  }
  
  wasPaused = false;
  autoFrameSkipLastTime = time;
}

void systemScreenCapture(int a)
{
  char buffer[2048];

  if(captureFormat) {
    if(captureDir[0])
      sprintf(buffer, "%s/%s%02d.bmp", captureDir, sdlGetFilename(filename), a);
    else
      sprintf(buffer, "%s%02d.bmp", filename, a);

    emulator.emuWriteBMP(buffer);
  } else {
    if(captureDir[0])
      sprintf(buffer, "%s/%s%02d.png", captureDir, sdlGetFilename(filename), a);
    else
      sprintf(buffer, "%s%02d.png", filename, a);
    emulator.emuWritePNG(buffer);
  }

  systemScreenMessage("Screen capture");
}

void soundCallback(void *,u8 *stream,int len)
{
  if(!emulating)
    return;
  SDL_mutexP(mutex);
  //  printf("Locked mutex\n");
  if(!speedup && !throttle) {
    while(sdlSoundLen < 2048*2) {
      if(emulating)
        SDL_CondWait(cond, mutex);
      else 
        break;
    }
  }
  if(emulating) {
    //  printf("Copying data\n");
    memcpy(stream, sdlBuffer, len);
  }
  sdlSoundLen = 0;
  if(mutex)
    SDL_mutexV(mutex);
}

void systemWriteDataToSoundBuffer()
{
  if(SDL_GetAudioStatus() != SDL_AUDIO_PLAYING)
    SDL_PauseAudio(0);
  bool cont = true;
  while(cont && !speedup && !throttle) {
    SDL_mutexP(mutex);
    //    printf("Waiting for len < 2048 (speed up %d)\n", speedup);
    if(sdlSoundLen < 2048*2)
      cont = false;
    SDL_mutexV(mutex);
  }

  int len = soundBufferLen;
  int copied = 0;
  if((sdlSoundLen+len) >= 2048*2) {
    //    printf("Case 1\n");
    memcpy(&sdlBuffer[sdlSoundLen],soundFinalWave, 2048*2-sdlSoundLen);
    copied = 2048*2 - sdlSoundLen;
    sdlSoundLen = 2048*2;
    SDL_CondSignal(cond);
    cont = true;
    if(!speedup && !throttle) {
      while(cont) {
        SDL_mutexP(mutex);
        if(sdlSoundLen < 2048*2)
          cont = false;
        SDL_mutexV(mutex);
      }
      memcpy(&sdlBuffer[0],&(((u8 *)soundFinalWave)[copied]),
             soundBufferLen-copied);
      sdlSoundLen = soundBufferLen-copied;
    } else {
      memcpy(&sdlBuffer[0], &(((u8 *)soundFinalWave)[copied]), 
soundBufferLen);
    }
  } else {
    //    printf("case 2\n");
    memcpy(&sdlBuffer[sdlSoundLen], soundFinalWave, soundBufferLen);
    sdlSoundLen += soundBufferLen;
  }
}

bool systemSoundInit()
{
  SDL_AudioSpec audio;

  switch(soundQuality) {
  case 1:
    audio.freq = 44100;
    soundBufferLen = 1470*2;
    break;
  case 2:
    audio.freq = 22050;
    soundBufferLen = 736*2;
    break;
  case 4:
    audio.freq = 11025;
    soundBufferLen = 368*2;
    break;
  }
  audio.format=AUDIO_S16SYS;
  audio.channels = 2;
  audio.samples = 1024;
  audio.callback = soundCallback;
  audio.userdata = NULL;
  if(SDL_OpenAudio(&audio, NULL)) {
    fprintf(stderr,"Failed to open audio: %s\n", SDL_GetError());
    return false;
  }
  soundBufferTotalLen = soundBufferLen*10;
  cond = SDL_CreateCond();
  mutex = SDL_CreateMutex();
  sdlSoundLen = 0;
  systemSoundOn = true;
  return true;
}

void systemSoundShutdown()
{
  SDL_mutexP(mutex);
  SDL_CondSignal(cond);
  SDL_mutexV(mutex);
  SDL_DestroyCond(cond);
  cond = NULL;
  SDL_DestroyMutex(mutex);
  mutex = NULL;
  SDL_CloseAudio();
}

void systemSoundPause()
{
  SDL_PauseAudio(1);
}

void systemSoundResume()
{
  SDL_PauseAudio(0);
}

void systemSoundReset()
{
}

u32 systemGetClock()
{
  return SDL_GetTicks();
}

void systemUpdateMotionSensor()
{
  if(sdlMotionButtons[KEY_LEFT]) {
    sensorX += 3;
    if(sensorX > 2197)
      sensorX = 2197;
    if(sensorX < 2047)
      sensorX = 2057;
  } else if(sdlMotionButtons[KEY_RIGHT]) {
    sensorX -= 3;
    if(sensorX < 1897)
      sensorX = 1897;
    if(sensorX > 2047)
      sensorX = 2037;
  } else if(sensorX > 2047) {
    sensorX -= 2;
    if(sensorX < 2047)
      sensorX = 2047;
  } else {
    sensorX += 2;
    if(sensorX > 2047)
      sensorX = 2047;
  }

  if(sdlMotionButtons[KEY_UP]) {
    sensorY += 3;
    if(sensorY > 2197)
      sensorY = 2197;
    if(sensorY < 2047)
      sensorY = 2057;
  } else if(sdlMotionButtons[KEY_DOWN]) {
    sensorY -= 3;
    if(sensorY < 1897)
      sensorY = 1897;
    if(sensorY > 2047)
      sensorY = 2037;
  } else if(sensorY > 2047) {
    sensorY -= 2;
    if(sensorY < 2047)
      sensorY = 2047;
  } else {
    sensorY += 2;
    if(sensorY > 2047)
      sensorY = 2047;
  }    
}

int systemGetSensorX()
{
  return sensorX;
}

int systemGetSensorY()
{
  return sensorY;
}

void systemGbPrint(u8 *data,int pages,int feed,int palette, int contrast)
{
}

void systemScreenMessage(const char *msg)
{
  screenMessage = true;
  screenMessageTime = systemGetClock();
  if(strlen(msg) > 20) {
    strncpy(screenMessageBuffer, msg, 20);
    screenMessageBuffer[20] = 0;
  } else
    strcpy(screenMessageBuffer, msg);  
}

bool systemCanChangeSoundQuality()
{
  return true;
}

bool systemPauseOnFrame()
{
  if(pauseNextFrame) {
    paused = true;
    pauseNextFrame = false;
    return true;
  }
  return false;
}

void systemGbBorderOn()
{
  srcWidth = 256;
  srcHeight = 224;
  gbBorderLineSkip = 256;
  gbBorderColumnSkip = 48;
  gbBorderRowSkip = 40;

  destWidth = (sizeOption+1)*srcWidth;
  destHeight = (sizeOption+1)*srcHeight;
  
  surface = SDL_SetVideoMode(destWidth, destHeight, 16,
                             SDL_SWSURFACE|
                             (fullscreen ? SDL_FULLSCREEN : 0));  

  switch(systemColorDepth) {
  case 16:
    sdlStretcher = sdlStretcher16[sizeOption];
    break;
  case 24:
    sdlStretcher = sdlStretcher24[sizeOption];
    break;
  case 32:
    sdlStretcher = sdlStretcher32[sizeOption];
    break;
  default:
    fprintf(stderr, "Unsupported resolution: %d\n", systemColorDepth);
    exit(-1);
  }

  if(systemColorDepth == 16) {
    if(sdlCalculateMaskWidth(surface->format->Gmask) == 6) {
      Init_2xSaI(565);
      RGB_LOW_BITS_MASK = 0x821;
    } else {
      Init_2xSaI(555);
      RGB_LOW_BITS_MASK = 0x421;      
    }
    if(cartridgeType == 2) {
      for(int i = 0; i < 0x10000; i++) {
        systemColorMap16[i] = (((i >> 1) & 0x1f) << systemBlueShift) |
          (((i & 0x7c0) >> 6) << systemGreenShift) |
          (((i & 0xf800) >> 11) << systemRedShift);  
      }      
    } else {
      for(int i = 0; i < 0x10000; i++) {
        systemColorMap16[i] = ((i & 0x1f) << systemRedShift) |
          (((i & 0x3e0) >> 5) << systemGreenShift) |
          (((i & 0x7c00) >> 10) << systemBlueShift);  
      }
    }
    srcPitch = srcWidth * 2+4;
  } else {
    if(systemColorDepth != 32)
      filterFunction = NULL;
    RGB_LOW_BITS_MASK = 0x010101;
    if(systemColorDepth == 32) {
      Init_2xSaI(32);
    }
    for(int i = 0; i < 0x10000; i++) {
      systemColorMap32[i] = ((i & 0x1f) << systemRedShift) |
        (((i & 0x3e0) >> 5) << systemGreenShift) |
        (((i & 0x7c00) >> 10) << systemBlueShift);  
    }
    if(systemColorDepth == 32)
      srcPitch = srcWidth*4 + 4;
    else
      srcPitch = srcWidth*3;
  }
}
