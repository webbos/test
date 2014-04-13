//
//  GConfigMenuLayer.m
//  Gorillas
//
//  Created by Maarten Billemont on 27/11/10.
//  Copyright 2010 lhunath (Maarten Billemont). All rights reserved.
//

#import "GConfigMenuLayer.h"

@implementation GConfigMenuLayer

- (id)initWithDelegate:(id<NSObject, PearlCCMenuDelegate, PearlCCConfigMenuDelegate>)aDelegate logo:(CCMenuItem *)aLogo
     settingsFromArray:(NSArray *)settings {

    if (!(self = [super initWithDelegate:aDelegate logo:aLogo settingsFromArray:settings]))
        return self;

    self.colorGradient = ccc4l( 0x00000000 );
    self.opacity = 0x00;
    self.outerPadding = PearlMarginMake( 0, 0, 0, 0 );
    self.innerRatio = 0;
    self.background = [CCSprite spriteWithFile:@"menu-back.png"];

    return self;
}

@end
