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
 
#import "SDL.h"
#import "MainClass.h"
#import "openfile.h"
#import "KeyConfig.h"
#import <sys/param.h> /* for MAXPATHLEN */
#import <unistd.h>

extern void sdlSetDefaultPreferences();
extern void soundSetQuality(int quality);

/* Use this flag to determine whether we use SDLMain.nib or not */
#define		SDL_USE_NIB_FILE	1

#define prefs [NSUserDefaults standardUserDefaults]

static int    gArgc;
static char  **gArgv;
static BOOL   gFinderLaunch;
int runAgain = 0, cheatCBA = 0, cheatGSA = 0;
extern int stopPoll;
int keyConfig[12], configArray[20];
char keyArray[12][12], code[6][256];
extern bool paused;
extern bool wasPaused;
NSString *cheatString, * biosPath;
void emu_main();
char launchFile[1024];
NSString *keyLeftString, *keyRightString, *keyUpString, *keyDownString, *keyAString, *keyBString, *keyLString, *keyRString, *keyStartString, *keySelectString, *keySpeedString, *keyCaptureString;

//Config externs
enum {
  KEY_LEFT, KEY_RIGHT,
  KEY_UP, KEY_DOWN,
  KEY_BUTTON_A, KEY_BUTTON_B,
  KEY_BUTTON_START, KEY_BUTTON_SELECT,
  KEY_BUTTON_L, KEY_BUTTON_R,
  KEY_BUTTON_SPEED, KEY_BUTTON_CAPTURE
};

extern unsigned short joypad[4][12];
extern int cartridgeType;

@interface SDLApplication : NSApplication
@end

@implementation SDLApplication
/* Invoked from the Quit menu item */
- (void)terminate:(id)sender
{
    if (emulating)
        {
            done = true;
            emulating = false;
        }
    else
        {
            exit(0);
        }
}
@end


SDLMain *gSDLMain = NULL;
char biosFile[1024];
bool changeType;

/* The main class of the application, the application's delegate */
@implementation SDLMain

- (void) openHomepage:(id)sender
{
[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://software.emuscene.com"]];
}

- (void) donate:(id)sender
{
[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://www.paypal.com/xclick/business=payments%40victoly.com&item_name=EmuScene+Donation&no_note=1&tax=0&currency_code=USD"]];
}

- (void) quit:(id)sender
{
    if (emulating)
        {
            done = true;
            emulating = false;
        }
    else
        {
            exit(0);
        }
}

- (void) openPrefs:(id)sender
{
    paused = true;
    SDL_PauseAudio(paused);
    wasPaused = true;

    [self loadConfig];
    [prefsWindow makeKeyAndOrderFront:self];
}

- (void) closePrefsNull:(id)sender
{
    [prefsWindow orderOut:self];
    
    paused = false;
    SDL_PauseAudio(paused);
    wasPaused = false;
}

- (void) loadConfig
{
    [frameskip selectItemAtIndex:[prefs integerForKey:@"frameskip"]];
    [videoSize selectItemAtIndex:[prefs integerForKey:@"sizeOption"]];
    [videoFullscreen setState:[prefs integerForKey:@"fullscreen"]];
    [useBios setState:[prefs integerForKey:@"useBios"]];
    [skipBios setState:[prefs integerForKey:@"skipBios"]];
    [videoFilter selectItemAtIndex:[prefs integerForKey:@"filter"]];
	[videoBorder setState:[prefs integerForKey:@"gbBorder"]];
    if ([prefs integerForKey:@"soundQuality"] == 4)
        [soundQuality selectItemAtIndex:2];
    else
        [soundQuality selectItemAtIndex:([prefs integerForKey:@"soundQuality"]-1)];
    [soundOn setState:(![prefs integerForKey:@"soundOff"])];
    [soundEcho setState:[prefs integerForKey:@"soundEcho"]];
    [soundLowPass setState:[prefs integerForKey:@"soundLowPass"]];
    [soundReverseStereo setState:[prefs integerForKey:@"soundReverse"]];
    //[flashSize selectItemAtIndex:[prefs integerForKey:@"flashSize"]];
    [interframe selectItemAtIndex:[prefs integerForKey:@"ifbType"]];
    [showSpeed setState:[prefs integerForKey:@"showSpeed"]];
	[throttle setState:[prefs integerForKey:@"throttle"]];
    [pauseWhenInactive setState:[prefs integerForKey:@"pauseWhenInactive"]];
    [realtimeClock setState:[prefs integerForKey:@"rtcEnabled"]];
    [changeFileType setState:[prefs integerForKey:@"changeType"]];
	[alwaysSpeedup setState:[prefs integerForKey:@"alwaysSpeedup"]];
}

- (void)closePrefs:(id)sender
{
    [prefs setInteger:[frameskip indexOfSelectedItem] forKey:@"frameskip"];
    [prefs setInteger:[videoSize indexOfSelectedItem] forKey:@"sizeOption"];
    [prefs setInteger:[videoFullscreen state] forKey:@"fullscreen"];
    [prefs setInteger:[useBios state] forKey:@"useBios"];
    [prefs setInteger:[skipBios state] forKey:@"skipBios"];
    [prefs setInteger:[videoFilter indexOfSelectedItem] forKey:@"filter"];
	[prefs setInteger:[videoBorder state] forKey:@"gbBorder"];
    if (([soundQuality indexOfSelectedItem] + 1) == 3)
		[prefs setInteger:4 forKey:@"soundQuality"];
    else
        [prefs setInteger:([soundQuality indexOfSelectedItem] + 1) forKey:@"soundQuality"];
    [prefs setInteger:(![soundOn state]) forKey:@"soundOff"];
    [prefs setInteger:[soundEcho state] forKey:@"soundEcho"];
    [prefs setInteger:[soundLowPass state] forKey:@"soundLowPass"];
    [prefs setInteger:[soundReverseStereo state] forKey:@"soundReverse"];
    //[prefs setInteger:[flashSize indexOfSelectedItem] forKey:@"flashSize"];
    [prefs setInteger:[interframe indexOfSelectedItem] forKey:@"ifbType"];
    [prefs setInteger:[showSpeed state] forKey:@"showSpeed"];
    if (![soundOn state])
            {
            if ([throttle state])
                [prefs setInteger:65 forKey:@"throttle"];
            else
                [prefs setInteger:0 forKey:@"throttle"];
            }
        else
        {
            [prefs setInteger:0 forKey:@"throttle"];
        }
    [prefs setInteger:[pauseWhenInactive state] forKey:@"pauseWhenInactive"];
    [prefs setInteger:[realtimeClock state] forKey:@"rtcEnabled"];
    [prefs setInteger:[interframe indexOfSelectedItem] forKey:@"ifbType"];
    [prefs setInteger:[changeFileType state] forKey:@"changeType"];
	
	[prefs setInteger:[alwaysSpeedup state] forKey:@"alwaysSpeedup"];
	
    [prefsWindow orderOut:self];
    [prefs synchronize];
        
	paused = !paused;
	SDL_PauseAudio(paused);
	if(paused)
		wasPaused = true;
}


-(void) defaultPrefs:(id)sender
{
    BOOL isOK;
    NSString * path = [NSString stringWithString:@"~/Library/Preferences/VisualBoyAdvance.plist"];
    path = [path stringByExpandingTildeInPath];
    
    if( [[NSFileManager defaultManager] fileExistsAtPath:path] )
            isOK = [[NSFileManager defaultManager] removeFileAtPath:path handler:nil];
            
    sdlSetDefaultPreferences();
    [self loadConfig];
}

- (void) openRomFromMenu:(id)sender
{
    if (emulating)
    {
        runAgain = 1;
        emulating = false;
    }
    else
    {
        emu_main();
    }
}

-(void) changeCreator:(char *) filename
{
    NSNumber *fileType = [NSNumber numberWithUnsignedLong:'Cart'];
    NSNumber *fileCreator = [NSNumber numberWithUnsignedLong:'vboy'];
    
    NSString * fileString = [[NSString alloc] initWithCString:filename];
    
    [[NSFileManager defaultManager] changeFileAttributes:[NSDictionary dictionaryWithObject:fileType forKey:NSFileHFSTypeCode] atPath:fileString];
    
    [[NSFileManager defaultManager] changeFileAttributes:[NSDictionary dictionaryWithObject:fileCreator forKey:NSFileHFSCreatorCode] atPath:fileString];
}

-(void) changeSaveCreator:(char *) filename
{
    NSNumber *fileType = [NSNumber numberWithUnsignedLong:'savf'];
    NSNumber *fileCreator = [NSNumber numberWithUnsignedLong:'vboy'];
    
    NSString * fileString = [[NSString alloc] initWithCString:filename];
    
    [[NSFileManager defaultManager] changeFileAttributes:[NSDictionary dictionaryWithObject:fileType forKey:NSFileHFSTypeCode] atPath:fileString];
    
    [[NSFileManager defaultManager] changeFileAttributes:[NSDictionary dictionaryWithObject:fileCreator forKey:NSFileHFSCreatorCode] atPath:fileString];
}

-(void) changeSgmCreator:(char *) statename
{
    NSNumber *fileType = [NSNumber numberWithUnsignedLong:'sgmf'];
    NSNumber *fileCreator = [NSNumber numberWithUnsignedLong:'vboy'];
    
    NSString * fileString = [[NSString alloc] initWithCString:statename];
    
    [[NSFileManager defaultManager] changeFileAttributes:[NSDictionary dictionaryWithObject:fileType forKey:NSFileHFSTypeCode] atPath:fileString];
    
    [[NSFileManager defaultManager] changeFileAttributes:[NSDictionary dictionaryWithObject:fileCreator forKey:NSFileHFSCreatorCode] atPath:fileString];
}

/* Set the working directory to the .app's parent directory */
- (void) setupWorkingDirectory:(BOOL)shouldChdir
{
    char parentdir[MAXPATHLEN];
    char *c;
    
    strncpy ( parentdir, gArgv[0], sizeof(parentdir) );
    c = (char*) parentdir;

    while (*c != '\0')     /* go to end */
        c++;
    
    while (*c != '/')      /* back up to parent */
        c--;
    
    *c++ = '\0';             /* cut off last part (binary name) */
  
    if (shouldChdir)
    {
      assert ( chdir (parentdir) == 0 );   /* chdir to the binary app's parent */
      assert ( chdir ("../../../") == 0 ); /* chdir to the .app's parent */
    }
}

- (void) addCheatCBA
{
    int i;
    char desc[10];
    for (i=0; i<6; i++)
        {
         if (code[i][0] != '\0')
            cheatsAddCBACode(code[i], desc);
        }
}

- (void) addCheatGSA
{
    int i;
    char desc[10];
    for (i=0; i<6; i++)
        {
         if (code[i][0] != '\0')
            cheatsAddGSACode(code[i], desc, false);
        }
}

/* Called before applicationDidFinishLaunching, handles associated file opening */
- (BOOL) application: (NSApplication *) SDLApplication openFile: (NSString *) filename
{
    if (filename)
    {
        strcpy(launchFile, [filename UTF8String]);
        if (emulating)
            {
                runAgain = 1;
                emulating = false;
            }
        return TRUE;
    }
    else
    {
        return FALSE;
    }
}

/* Called when the internal event loop has just started running */
- (void) applicationDidFinishLaunching: (NSNotification *) note
{
    
    gSDLMain = self;

    /* Set the working directory to the .app's parent directory */
    //[self loadConfig];
    [self setupWorkingDirectory:gFinderLaunch];

    /* Hand off to main application code */
    emu_main();
}

@end

@implementation CheatClass

-(void) readCheatCBA:(id)sender
{
    cheatCBA = 1;
    cheatString = [NSString stringWithString:[cheatField stringValue]];
    [cheatString getCString:code[0]];
    cheatString = [NSString stringWithString:[cheatField2 stringValue]];
    [cheatString getCString:code[1]];
    cheatString = [NSString stringWithString:[cheatField3 stringValue]];
    [cheatString getCString:code[2]];
    cheatString = [NSString stringWithString:[cheatField4 stringValue]];
    [cheatString getCString:code[3]];
    cheatString = [NSString stringWithString:[cheatField5 stringValue]];
    [cheatString getCString:code[4]];
    cheatString = [NSString stringWithString:[cheatField6 stringValue]];
    [cheatString getCString:code[5]];
    [cheatWindow orderOut:self];
}

-(void) readCheatGSA:(id)sender
{
    cheatGSA = 1;
    cheatString = [NSString stringWithString:[cheatFieldGSA stringValue]];
    [cheatString getCString:code[0]];
    cheatString = [NSString stringWithString:[cheatFieldGSA2 stringValue]];
    [cheatString getCString:code[1]];
    cheatString = [NSString stringWithString:[cheatFieldGSA3 stringValue]];
    [cheatString getCString:code[2]];
    cheatString = [NSString stringWithString:[cheatFieldGSA4 stringValue]];
    [cheatString getCString:code[3]];
    cheatString = [NSString stringWithString:[cheatFieldGSA5 stringValue]];
    [cheatString getCString:code[4]];
    cheatString = [NSString stringWithString:[cheatFieldGSA6 stringValue]];
    [cheatString getCString:code[5]];
    [cheatWindowGSA orderOut:self];
}


- (BOOL)validateMenuItem:(NSMenuItem*)anItem
{
if (emulating)
    return NO;
else
    return YES;
}
    
-(void) openCheatCBA:(id)sender
{
    [cheatWindow makeKeyAndOrderFront:self];
}

-(void) openCheatGSA:(id)sender
{
    [cheatWindowGSA makeKeyAndOrderFront:self];
}

-(void) disableCheats
{
    [cheatMenuCBA setAction:NULL];
    [cheatMenuGSA setAction:NULL];
}

-(void) enableCheats
{
    [cheatMenuCBA setAction:@selector(openCheatCBA:)];
    [cheatMenuGSA setAction:@selector(openCheatGSA:)];
}


@end

@implementation MenuClass

- (void) freezeState:(id)sender
{
sdlWriteState(0);
}

- (void) defrostState:(id)sender
{
sdlReadState(0);
}

- (void) closeRom:(id)sender
{
    emulating = false;
}

-(void) resetEmulation:(id)sender
{
    sdlEmuReset();
}

-(void) pauseEmulation:(id)sender
{
    sdlEmuPause();
}

- (BOOL)validateMenuItem:(NSMenuItem*)anItem
{
if (emulating)
    return YES;
else
    return NO;
}
@end

@implementation ConfigClass

- (BOOL)validateMenuItem:(NSMenuItem*)anItem
{
if (emulating)
    return NO;
else
    return YES;
}

- (void) closePrefsNull:(id)sender
{
    [configWindow orderOut:self];
    SDL_Quit();
}

- (void) beginConfig:(id)sender
{
int num = config_main();
[self loadKeyValues];
[configWindow makeKeyAndOrderFront:self];
if (num)
    {
        NSRunInformationalAlertPanel(@"Notice!", @"Before you configure your joystick(s), please press the Calibrate button and move your joystick(s) in all directions.  Then press any key to exit the calibration and proceed to assign all keys.\n",@"OK",NULL,NULL);
        [calibrateButton setEnabled:YES];
    }
else
    {
        [calibrateButton setEnabled:NO];
    }
}

- (void) endConfig:(id)sender
{
    [configWindow orderOut:self];
    [prefs setInteger:[leftField intValue] forKey:@"Joy0_Left"];
    [prefs setInteger:[rightField intValue] forKey:@"Joy0_Right"];
    [prefs setInteger:[upField intValue] forKey:@"Joy0_Up"];
    [prefs setInteger:[downField intValue] forKey:@"Joy0_Down"];
    [prefs setInteger:[aField intValue] forKey:@"Joy0_A"];
    [prefs setInteger:[bField intValue] forKey:@"Joy0_B"];
    [prefs setInteger:[lField intValue] forKey:@"Joy0_L"];
    [prefs setInteger:[rField intValue] forKey:@"Joy0_R"];
    [prefs setInteger:[startField intValue] forKey:@"Joy0_Start"];
    [prefs setInteger:[selectField intValue] forKey:@"Joy0_Select"];
    [prefs setInteger:[speedField intValue] forKey:@"Joy0_Speed"];
    [prefs setInteger:[captureField intValue] forKey:@"Joy0_Capture"];
    [prefs synchronize];
    SDL_Quit();
}

-(void)loadKeyValues
{
    [leftField setIntValue:[prefs integerForKey:@"Joy0_Left"]];
    [rightField setIntValue:[prefs integerForKey:@"Joy0_Right"]];
    [upField setIntValue:[prefs integerForKey:@"Joy0_Up"]];
    [downField setIntValue:[prefs integerForKey:@"Joy0_Down"]];
    [aField setIntValue:[prefs integerForKey:@"Joy0_A"]];
    [bField setIntValue:[prefs integerForKey:@"Joy0_B"]];
    [lField setIntValue:[prefs integerForKey:@"Joy0_L"]];
    [rField setIntValue:[prefs integerForKey:@"Joy0_R"]];
    [startField setIntValue:[prefs integerForKey:@"Joy0_Start"]];
    [selectField setIntValue:[prefs integerForKey:@"Joy0_Select"]];
    [speedField setIntValue:[prefs integerForKey:@"Joy0_Speed"]];
    [captureField setIntValue:[prefs integerForKey:@"Joy0_Capture"]];
}
-(void)defaultKeys:(id)sender
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
    [self loadKeyValues];
}

- (void)calibrate:(id)sender
{
    [OKButton setEnabled:NO];
    [CancelButton setEnabled:NO];
    [defaultButton setEnabled:NO];
    while (!stopPoll) {
    calibrate();
    }
    stopPoll = 0;
    [OKButton setEnabled:YES];
    [CancelButton setEnabled:YES];
    [defaultButton setEnabled:YES];
}

- (void)pollUp:(id)sender
{
    [OKButton setEnabled:NO];
    [CancelButton setEnabled:NO];
    [defaultButton setEnabled:NO];
    while (!stopPoll) {
        keyConfig[0] = poll();
    }
    [upField setIntValue:keyConfig[0]];
    stopPoll = 0;
    [OKButton setEnabled:YES];
    [CancelButton setEnabled:YES];
    [defaultButton setEnabled:YES];
}

- (void)pollDown:(id)sender
{
    [OKButton setEnabled:NO];
    [CancelButton setEnabled:NO];
    [defaultButton setEnabled:NO];
    while (!stopPoll) {
        keyConfig[1] = poll();
    }
    [downField setIntValue:keyConfig[1]];
    stopPoll = 0;
    [OKButton setEnabled:YES];
    [CancelButton setEnabled:YES];
    [defaultButton setEnabled:YES];
}

- (void)pollLeft:(id)sender
{
    [OKButton setEnabled:NO];
    [CancelButton setEnabled:NO];
    [defaultButton setEnabled:NO];
    while (!stopPoll) {
        keyConfig[2] = poll();
    }
    [leftField setIntValue:keyConfig[2]];
    stopPoll = 0;
    [OKButton setEnabled:YES];
    [CancelButton setEnabled:YES];
    [defaultButton setEnabled:YES];
}

- (void)pollRight:(id)sender
{
    [OKButton setEnabled:NO];
    [CancelButton setEnabled:NO];
    [defaultButton setEnabled:NO];
    while (!stopPoll) {
        keyConfig[3] = poll();
    }
    [rightField setIntValue:keyConfig[3]];
    stopPoll = 0;
    [OKButton setEnabled:YES];
    [CancelButton setEnabled:YES];
    [defaultButton setEnabled:YES];
}

- (void)pollA:(id)sender
{
    [OKButton setEnabled:NO];
    [CancelButton setEnabled:NO];
    [defaultButton setEnabled:NO];
    while (!stopPoll) {
        keyConfig[4] = poll();
    }
    [aField setIntValue:keyConfig[4]];
    stopPoll = 0;
    [OKButton setEnabled:YES];
    [CancelButton setEnabled:YES];
    [defaultButton setEnabled:YES];
}

- (void)pollB:(id)sender
{
    [OKButton setEnabled:NO];
    [CancelButton setEnabled:NO];
    [defaultButton setEnabled:NO];
    while (!stopPoll) {
        keyConfig[5] = poll();
    }
    [bField setIntValue:keyConfig[5]];
    stopPoll = 0;
    [OKButton setEnabled:YES];
    [CancelButton setEnabled:YES];
    [defaultButton setEnabled:YES];
}

- (void)pollL:(id)sender
{
    [OKButton setEnabled:NO];
    [CancelButton setEnabled:NO];
    [defaultButton setEnabled:NO];
    while (!stopPoll) {
        keyConfig[6] = poll();
    }
    [lField setIntValue:keyConfig[6]];
    stopPoll = 0;
    [OKButton setEnabled:YES];
    [CancelButton setEnabled:YES];
    [defaultButton setEnabled:YES];
}

- (void)pollR:(id)sender
{
    [OKButton setEnabled:NO];
    [CancelButton setEnabled:NO];
    [defaultButton setEnabled:NO];
    while (!stopPoll) {
        keyConfig[7] = poll();
    }
    [rField setIntValue:keyConfig[7]];
    stopPoll = 0;
    [OKButton setEnabled:YES];
    [CancelButton setEnabled:YES];
    [defaultButton setEnabled:YES];
}

- (void)pollStart:(id)sender
{
    [OKButton setEnabled:NO];
    [CancelButton setEnabled:NO];
    [defaultButton setEnabled:NO];
    while (!stopPoll) {
        keyConfig[8] = poll();
    }
    [startField setIntValue:keyConfig[8]];
    stopPoll = 0;
    [OKButton setEnabled:YES];
    [CancelButton setEnabled:YES];
    [defaultButton setEnabled:YES];
}

- (void)pollSelect:(id)sender
{
    [OKButton setEnabled:NO];
    [CancelButton setEnabled:NO];
    [defaultButton setEnabled:NO];
    while (!stopPoll) {
        keyConfig[9] = poll();
    }
    [selectField setIntValue:keyConfig[9]];
    stopPoll = 0;
    [OKButton setEnabled:YES];
    [CancelButton setEnabled:YES];
    [defaultButton setEnabled:YES];
}

- (void)pollCapture:(id)sender
{
    [OKButton setEnabled:NO];
    [CancelButton setEnabled:NO];
    [defaultButton setEnabled:NO];
    while (!stopPoll) {
        keyConfig[10] = poll();
    }
    [captureField setIntValue:keyConfig[10]];
    stopPoll = 0;
    [OKButton setEnabled:YES];
    [CancelButton setEnabled:YES];
    [defaultButton setEnabled:YES];
}

- (void)pollSpeed:(id)sender
{
    [OKButton setEnabled:NO];
    [CancelButton setEnabled:NO];
    [defaultButton setEnabled:NO];
    while (!stopPoll) {
        keyConfig[11] = poll();
    }
    [speedField setIntValue:keyConfig[11]];
    stopPoll = 0;
    [OKButton setEnabled:YES];
    [CancelButton setEnabled:YES];
    [defaultButton setEnabled:YES];
}

@end

#ifdef main
#  undef main
#endif


/* Main entry point to executable - should *not* be SDL_main! */
int main (int argc, char **argv)
{

    /* Copy the arguments into a global variable */
    int i;
    /* This is passed if we are launched by double-clicking */
    if ( argc >= 2 && strncmp (argv[1], "-psn", 4) == 0 ) {
        gArgc = 1;
	gFinderLaunch = YES;
    } else {
        gArgc = argc;
	gFinderLaunch = NO;
    }
    gArgv = (char**) malloc (sizeof(*gArgv) * (gArgc+1));
    assert (gArgv != NULL);
    for (i = 0; i < gArgc; i++)
        gArgv[i] = argv[i];
    gArgv[i] = NULL;

    [SDLApplication sharedApplication];
    [NSApp run];
    return 0;
}

void emu_main()
{
    int status = 0;
    /* Hand off to main application code */
    while(!done)
    {
    status = SDL_main (gArgc, gArgv);
    if (runAgain)
        {
        runAgain = 0;
        launchFile[0] = '\0';
        continue;
        }
    else
        {
        break;
        }
    }

    /* We're done, thank you for playing */
    if (done)
        exit(status);
    else
        NSApplicationMain(gArgc, (const char**)gArgv);
}
