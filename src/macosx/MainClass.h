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
 
#import <Cocoa/Cocoa.h>

@interface SDLMain : NSObject
{
    IBOutlet NSWindow *prefsWindow;
    IBOutlet NSButton *skipBios;
    IBOutlet NSButton *pauseWhenInactive;
    IBOutlet NSButton *realtimeClock;
    IBOutlet NSPopUpButton *interframe;
    IBOutlet NSButton *soundEcho;
    IBOutlet NSButton *soundLowPass;
    IBOutlet NSButton *soundOn;
    IBOutlet NSPopUpButton *soundQuality;
    IBOutlet NSButton *soundReverseStereo;
    //IBOutlet NSPopUpButton *flashSize;
    IBOutlet NSButton *videoBorder;
    IBOutlet NSPopUpButton *videoFilter;
    IBOutlet NSButton *videoFullscreen;
    IBOutlet NSPopUpButton *videoSize;
    IBOutlet NSPopUpButton *frameskip;
    IBOutlet NSButton *showSpeed;
    IBOutlet NSButton *useBios;
    IBOutlet NSButton *throttle;
    IBOutlet NSButton *changeFileType;
	IBOutlet NSButton *alwaysSpeedup;
}
- (IBAction)closePrefs:(id)sender;
- (IBAction)loadConfig;
- (IBAction)closePrefsNull:(id)sender;
- (IBAction)openPrefs:(id)sender;
- (IBAction)openRomFromMenu:(id)sender;
- (IBAction)quit:(id)sender;
- (IBAction)changeCreator:(char *)filename;
- (IBAction)changeSaveCreator:(char *)filename;
- (IBAction)changeSgmCreator:(char *)statename;
- (IBAction)addCheatCBA;
- (IBAction)addCheatGSA;
@end

@interface CheatClass : NSObject
{
    IBOutlet NSTextField *cheatField;
    IBOutlet NSTextField *cheatField2;
    IBOutlet NSTextField *cheatField3;
    IBOutlet NSTextField *cheatField4;
    IBOutlet NSTextField *cheatField5;
    IBOutlet NSTextField *cheatField6;
    IBOutlet NSWindow *cheatWindow;
    IBOutlet NSTextField *cheatFieldGSA;
    IBOutlet NSTextField *cheatFieldGSA2;
    IBOutlet NSTextField *cheatFieldGSA3;
    IBOutlet NSTextField *cheatFieldGSA4;
    IBOutlet NSTextField *cheatFieldGSA5;
    IBOutlet NSTextField *cheatFieldGSA6;
    IBOutlet NSWindow *cheatWindowGSA;
    IBOutlet NSMenuItem *cheatMenuCBA;
    IBOutlet NSMenuItem *cheatMenuGSA;
    IBOutlet NSMenu *cheatMenu;
}
- (IBAction)disableCheats;
- (IBAction)enableCheats;
- (IBAction)readCheatCBA:(id)sender;
- (IBAction)readCheatGSA:(id)sender;
- (IBAction)openCheatCBA:(id)sender;
- (IBAction)openCheatGSA:(id)sender;
@end

@interface MenuClass : NSObject
- (IBAction)closeRom:(id)sender;
- (IBAction)resetEmulation:(id)sender;
- (IBAction)pauseEmulation:(id)sender;
@end

@interface ConfigClass : NSObject
{
    IBOutlet NSButton *calibrateButton;
    IBOutlet NSButton *defaultButton;
    IBOutlet NSButton *OKButton;
    IBOutlet NSButton *CancelButton;
    IBOutlet NSTextField *aField;
    IBOutlet NSTextField *bField;
    IBOutlet NSTextField *downField;
    IBOutlet NSTextField *leftField;
    IBOutlet NSTextField *lField;
    IBOutlet NSTextField *rField;
    IBOutlet NSTextField *rightField;
    IBOutlet NSTextField *selectField;
    IBOutlet NSTextField *startField;
    IBOutlet NSTextField *upField;
    IBOutlet NSTextField *captureField;
    IBOutlet NSTextField *speedField;
    IBOutlet NSWindow *configWindow;
    IBOutlet NSWindow *noteWindow;
}
- (void)loadKeyValues;
- (IBAction)beginConfig:(id)sender;
- (IBAction)endConfig:(id)sender;
- (IBAction)calibrate:(id)sender;
- (IBAction)pollA:(id)sender;
- (IBAction)pollB:(id)sender;
- (IBAction)pollCapture:(id)sender;
- (IBAction)pollSpeed:(id)sender;
- (IBAction)pollDown:(id)sender;
- (IBAction)pollL:(id)sender;
- (IBAction)pollLeft:(id)sender;
- (IBAction)pollR:(id)sender;
- (IBAction)pollRight:(id)sender;
- (IBAction)pollSelect:(id)sender;
- (IBAction)pollStart:(id)sender;
- (IBAction)pollUp:(id)sender;
@end

extern SDLMain *gSDLMain;
extern bool changeType;
extern int done;
extern int emulating;
void sdlEmuReset( void );
void sdlEmuPause( void );
void cheatsAddCBACode(const char *code, const char *desc);
void cheatsAddGSACode(const char *code, const char *desc, bool v3);
void sdlWriteState(int num);
void sdlReadState(int num);