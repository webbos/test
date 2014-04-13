/*
 * This file is part of Gorillas.
 *
 *  Gorillas is open software: you can use or modify it under the
 *  terms of the Java Research License or optionally a more
 *  permissive Commercial License.
 *
 *  Gorillas is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 *  You should have received a copy of the Java Research License
 *  along with Gorillas in the file named 'COPYING'.
 *  If not, see <http://stuff.lhunath.com/COPYING>.
 */

//
//  BuildingsLayer.m
//  Gorillas
//
//  Created by Maarten Billemont on 25/10/08.
//  Copyright 2008-2009, lhunath (Maarten Billemont). All rights reserved.
//

#import "BuildingsLayer.h"
#import "PearlGLUtils.h"

@implementation BuildingsLayer {

@private
    float buildingWidthRatio, buildingHeightRatio, lightRatio;

    NSUInteger windowCount;

    GLuint buildingsVertexBuffer, buildingsIndicesBuffer;
    GLuint windowsIndicesBuffer, windowsVertexBuffer;
    GLuint buildingsVertexObject[2];
    GLuint windowsVertexObject;
}

- (id)init {

    if (!(self = [self initWithWidthRatio:1 heightRatio:1 lightRatio:0]))
        return nil;

    return self;
}

- (id)initWithWidthRatio:(CGFloat)w heightRatio:(float)h lightRatio:(float)l {

    if (!(self = [super init]))
        return self;

    self.shaderProgram = [[CCShaderCache sharedShaderCache] programForKey:kCCShader_PositionColor];

    buildingWidthRatio = w;
    buildingHeightRatio = h;
    lightRatio = l;

    buildingsVertexObject[0] = 0;
    buildingsVertexObject[1] = 0;
    buildingsVertexBuffer = 0;
    buildingsIndicesBuffer = 0;
    windowsVertexObject = 0;
    windowsVertexBuffer = 0;
    windowsIndicesBuffer = 0;

    // Must reset before onEnter.  Others' onEnter depends on us being done.
    [self reset];

    return self;
}

- (BOOL)hitsBuilding:(CGPoint)pos {

    for (NSUInteger b = 0; b < _buildingCount; ++b)
        if (pos.y >= 0 && pos.y <= _buildings[b].size.height) if (pos.x >= _buildings[b].x && pos.x <= _buildings[b].x + _buildings[b].size.width)
            return YES;

    return NO;
}

- (void)reset {

    dbg(@"BuildingsLayer reset start");
    const GorillasConfig *config = [GorillasConfig get];

    const ccColor4B skyColor = ccc4l( [config.skyColor unsignedLongValue] );
    const ccColor4B wColor0 = ccc4shade( ccc4lighten( ccc4l( [config.windowColorOff unsignedLongValue] ), lightRatio ),
            skyColor, MAX(0, -lightRatio / 2) );
    const ccColor4B wColor1 = ccc4shade( ccc4lighten( ccc4l( [config.windowColorOn unsignedLongValue] ), lightRatio ),
            skyColor, MAX(0, -lightRatio / 2) );
    ccColor4B wColor10;
    wColor10.r = (wColor0.r + wColor1.r) / 2;
    wColor10.g = (wColor0.g + wColor1.g) / 2;
    wColor10.b = (wColor0.b + wColor1.b) / 2;
    wColor10.a = (wColor0.a + wColor1.a) / 2;

    const NSUInteger fixedFloors = [config.fixedFloors unsignedIntValue];
    const NSUInteger varFloors = [config.varFloors unsignedIntValue];
    const CGSize winSize = [CCDirector sharedDirector].winSize;
    const CGFloat buildingWidth = buildingWidthRatio * (winSize.width / [config.buildingAmount unsignedIntValue]);
    const CGFloat wWidthPt = buildingWidth / ([config.windowAmount unsignedIntValue] * 2 + 1);
    const CGFloat wPadPt = wWidthPt;
    const CGFloat wHeightPt = wWidthPt * 2;
    const CGFloat floorHeightPt = wHeightPt + wPadPt;

    // Calculcate buildings.
    windowCount = 0;
    _buildingCount = [config.buildingAmount unsignedIntValue] * 3;
    free( _buildings );
    if (!_buildingCount)
        return;
    _buildings = calloc( _buildingCount, sizeof(Building) );
    for (NSUInteger b = 0; b < _buildingCount; ++b) {
        // Building's position.
        _buildings[b].x = b * buildingWidth - buildingWidth * (_buildingCount - [config.buildingAmount unsignedIntValue]) / 2;

        // Building's size.
        NSUInteger addFloors = 0;
        if (varFloors)
            addFloors = (NSUInteger)(buildingHeightRatio * (((unsigned)PearlGameRandom()) % varFloors));
        _buildings[b].size = CGSizeMake( buildingWidth - 1, (fixedFloors + addFloors) * floorHeightPt + wPadPt );

        // Building's windows.
        _buildings[b].windowCount = (fixedFloors + addFloors) * [config.windowAmount unsignedIntValue];
        windowCount += _buildings[b].windowCount;

        // Building's color.
        _buildings[b].frontColor = ccc4lighten( ccc4shade( [config buildingColor], skyColor, -lightRatio ), lightRatio / 3 );
        _buildings[b].topColor = ccc4lighten( _buildings[b].frontColor, -_buildings[b].size.height / (winSize.height * 1.5f) );
        _buildings[b].backColor = ccc4lighten( _buildings[b].frontColor, -0.8f );
    }

    // Build vertex arrays.
    BuildingVertex *buildingVertices = calloc( 4                          /* amount of vertices per building */
                                               * _buildingCount            /* amount of buildings */,
            sizeof(BuildingVertex)     /* size of a vertex */);
    GLushort *buildingIndices = calloc( 6                          /* amount of indexes per window */
                                        * _buildingCount            /* amount of windows in all buildings */,
            sizeof(GLushort)           /* size of an index */);
    Vertex *windowVertices = calloc( 4                          /* amount of vertices per window */
                                     * windowCount              /* amount of windows in all buildings */,
            sizeof(Vertex)             /* size of a vertex */);
    GLushort *windowIndices = calloc( 6                          /* amount of indexes per window */
                                      * windowCount              /* amount of windows in all buildings */,
            sizeof(GLushort)           /* size of an index */);
    const CGFloat wPadPx = wPadPt; // * CC_CONTENT_§_FACTOR();
    const CGFloat wWidthPx = wWidthPt; // * CC_CONTENT_SCALE_FACTOR();
    const CGFloat wHeightPx = wHeightPt; // * CC_CONTENT_SCALE_FACTOR();
    const CGFloat floorHeightPx = floorHeightPt; // * CC_CONTENT_SCALE_FACTOR();
    for (NSUInteger w = 0, b = 0; b < _buildingCount; ++b) {

        const CGFloat bx = _buildings[b].x; // * CC_CONTENT_SCALE_FACTOR();
        const CGSize bs = CGSizeMake( _buildings[b].size.width, //    * CC_CONTENT_SCALE_FACTOR(),
                _buildings[b].size.height ); //   * CC_CONTENT_SCALE_FACTOR());
        const NSUInteger bv = b * 4;
        const NSUInteger bi = b * 6;

        buildingVertices[bv + 0].front.c = buildingVertices[bv + 1].front.c = _buildings[b].frontColor;
        buildingVertices[bv + 2].front.c = buildingVertices[bv + 3].front.c = _buildings[b].topColor;
        buildingVertices[bv + 0].backColor = buildingVertices[bv + 1].backColor = _buildings[b].backColor;
        buildingVertices[bv + 2].backColor = buildingVertices[bv + 3].backColor = _buildings[b].backColor;

        buildingVertices[bv + 0].front.p = ccp( bx, 0 );
        buildingVertices[bv + 1].front.p = ccp( bx + bs.width, 0 );
        buildingVertices[bv + 2].front.p = ccp( bx, 0 + bs.height );
        buildingVertices[bv + 3].front.p = ccp( bx + bs.width, 0 + bs.height );

        buildingIndices[bi + 0] = (GLushort)(bv + 0);
        buildingIndices[bi + 1] = (GLushort)(bv + 1);
        buildingIndices[bi + 2] = (GLushort)(bv + 2);
        buildingIndices[bi + 3] = (GLushort)(bv + 2);
        buildingIndices[bi + 4] = (GLushort)(bv + 3);
        buildingIndices[bi + 5] = (GLushort)(bv + 1);

        NSUInteger bw = 0, floor = 0;
        while (bw < _buildings[b].windowCount) {
            const CGFloat y = wPadPx + floor * floorHeightPx;

            for (CGFloat wx = wPadPx;
                 wx < bs.width - wWidthPx && bw < _buildings[b].windowCount;
                 wx += wPadPx + wWidthPx) {

                // Reason we don't use gameRandom for windows:
                // Window count across multiple resolution devices is unpredictable due to rounding errors.
                const BOOL isOff = random() % 100 < 20;
                const NSUInteger wv = (w + bw) * 4;
                const NSUInteger wi = (w + bw) * 6;

                windowVertices[wv + 0].c = windowVertices[wv + 1].c = isOff? wColor0: wColor10;
                windowVertices[wv + 2].c = windowVertices[wv + 3].c = isOff? wColor0: wColor1;

                windowVertices[wv + 0].p = ccp( bx + wx, y );
                windowVertices[wv + 1].p = ccp( bx + wx + wWidthPx, y );
                windowVertices[wv + 2].p = ccp( bx + wx, y + wHeightPx );
                windowVertices[wv + 3].p = ccp( bx + wx + wWidthPx, y + wHeightPx );

                windowIndices[wi + 0] = (GLushort)(wv + 0);
                windowIndices[wi + 1] = (GLushort)(wv + 1);
                windowIndices[wi + 2] = (GLushort)(wv + 2);
                windowIndices[wi + 3] = (GLushort)(wv + 2);
                windowIndices[wi + 4] = (GLushort)(wv + 3);
                windowIndices[wi + 5] = (GLushort)(wv + 1);

                ++bw;
            }

            ++floor;
        }
        if (bw != _buildings[b].windowCount)
        err(@"Windows vertex count not the same as window amount.");

        w += bw;
    }

    // Push our building data into VAO.
    glDeleteVertexArrays( 2, &buildingsVertexObject[0] );
    glGenVertexArrays( 2, &buildingsVertexObject[0] );
    ccGLBindVAO( buildingsVertexObject[0] );
    glDeleteBuffers( 1, &buildingsVertexBuffer );
    glDeleteBuffers( 1, &buildingsIndicesBuffer );
    glGenBuffers( 1, &buildingsVertexBuffer );
    glGenBuffers( 1, &buildingsIndicesBuffer );

    glBindBuffer( GL_ARRAY_BUFFER, buildingsVertexBuffer );
    glBufferData( GL_ARRAY_BUFFER, (GLsizeiptr)(sizeof(BuildingVertex) * _buildingCount * 4), buildingVertices, GL_DYNAMIC_DRAW );
    glEnableVertexAttribArray( kCCVertexAttrib_Position );
    glVertexAttribPointer( kCCVertexAttrib_Position, 2, GL_FLOAT, GL_FALSE, sizeof(BuildingVertex),
            (GLvoid *)offsetof(BuildingVertex, front) + offsetof(Vertex, p));
    glEnableVertexAttribArray( kCCVertexAttrib_Color );
    glVertexAttribPointer( kCCVertexAttrib_Color, 4, GL_UNSIGNED_BYTE, GL_TRUE, sizeof(BuildingVertex),
            (GLvoid *)offsetof(BuildingVertex, front) + offsetof(Vertex, c));
    glBindBuffer( GL_ELEMENT_ARRAY_BUFFER, buildingsIndicesBuffer );
    glBufferData( GL_ELEMENT_ARRAY_BUFFER, (GLsizeiptr)(sizeof(GLushort) * _buildingCount * 6), buildingIndices, GL_DYNAMIC_DRAW );

    ccGLBindVAO( buildingsVertexObject[1] );
    glBindBuffer( GL_ARRAY_BUFFER, buildingsVertexBuffer );
    glEnableVertexAttribArray( kCCVertexAttrib_Position );
    glVertexAttribPointer( kCCVertexAttrib_Position, 2, GL_FLOAT, GL_FALSE, sizeof(BuildingVertex),
            (GLvoid *)offsetof(BuildingVertex, front) + offsetof(Vertex, p));
    glEnableVertexAttribArray( kCCVertexAttrib_Color );
    glVertexAttribPointer( kCCVertexAttrib_Color, 4, GL_UNSIGNED_BYTE, GL_TRUE, sizeof(BuildingVertex),
            (GLvoid *)offsetof(BuildingVertex, backColor));
    glBindBuffer( GL_ELEMENT_ARRAY_BUFFER, buildingsIndicesBuffer );

    // Push our window data into VAO.
    glDeleteVertexArrays( 1, &windowsVertexObject );
    glGenVertexArrays( 1, &windowsVertexObject );
    ccGLBindVAO( windowsVertexObject );
    glDeleteBuffers( 1, &windowsVertexBuffer );
    glDeleteBuffers( 1, &windowsIndicesBuffer );
    glGenBuffers( 1, &windowsVertexBuffer );
    glGenBuffers( 1, &windowsIndicesBuffer );

    glBindBuffer( GL_ARRAY_BUFFER, windowsVertexBuffer );
    glBufferData( GL_ARRAY_BUFFER, (GLsizeiptr)(sizeof(Vertex) * windowCount * 4), windowVertices, GL_DYNAMIC_DRAW );
    glEnableVertexAttribArray( kCCVertexAttrib_Position );
    glVertexAttribPointer( kCCVertexAttrib_Position, 2, GL_FLOAT, GL_FALSE, sizeof(Vertex), (GLvoid *)offsetof(Vertex, p));
    glEnableVertexAttribArray( kCCVertexAttrib_Color );
    glVertexAttribPointer( kCCVertexAttrib_Color, 4, GL_UNSIGNED_BYTE, GL_TRUE, sizeof(Vertex), (GLvoid *)offsetof(Vertex, c));
    glBindBuffer( GL_ELEMENT_ARRAY_BUFFER, windowsIndicesBuffer );
    glBufferData( GL_ELEMENT_ARRAY_BUFFER, (GLsizeiptr)(sizeof(GLushort) * windowCount * 6), windowIndices, GL_DYNAMIC_DRAW );

    ccGLBindVAO( 0 );
    glBindBuffer( GL_ARRAY_BUFFER, 0 );
    glBindBuffer( GL_ELEMENT_ARRAY_BUFFER, 0 );
    CHECK_GL_ERROR_DEBUG();

    // Free the client side data.
    free( buildingVertices );
    free( buildingIndices );
    free( windowVertices );
    free( windowIndices );
}

- (void)draw {

    [super draw];

    CC_PROFILER_START_CATEGORY(kCCProfilerCategorySprite, @"BuildingsLayer - draw");
    CC_NODE_DRAW_SETUP();

    // = FRONT BUILDING =
    // Blend with DST_ALPHA (DST_ALPHA of 1 means draw SRC over DST; DST_ALPHA of 0 means hide SRC, leave DST).
    ccGLBlendFunc( GL_DST_ALPHA, GL_ONE_MINUS_DST_ALPHA );
    ccGLBindVAO( buildingsVertexObject[0] );
    glDrawElements( GL_TRIANGLES, (GLsizei)(_buildingCount * 6), GL_UNSIGNED_SHORT, 0 );

    // = FRONT WINDOWS =
    ccGLBindVAO( windowsVertexObject );
    glDrawElements( GL_TRIANGLES, (GLsizei)(windowCount * 6), GL_UNSIGNED_SHORT, 0 );

    // Drawing Rear Side.
    if (buildingHeightRatio == 1) {

        // = REAR WINDOWS =
        // Set opacity of DST to 1 where there are windows -> building back won't draw over it.
        ccGLBlendFunc( GL_ONE, GL_ZERO );
        glColorMask( GL_FALSE, GL_FALSE, GL_FALSE, GL_TRUE );
        glDrawElements( GL_TRIANGLES, (GLsizei)(windowCount * 6), GL_UNSIGNED_SHORT, 0 );
        glColorMask( GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE );

        // == REAR BUILDING =
        // Draw back of building where DST opacity is < 1.
        ccGLBindVAO( buildingsVertexObject[1] );
        ccGLBlendFunc( GL_ONE_MINUS_DST_ALPHA, GL_DST_ALPHA );
        glDrawElements( GL_TRIANGLES, (GLsizei)(_buildingCount * 6), GL_UNSIGNED_SHORT, 0 );
    }

    CHECK_GL_ERROR_DEBUG();
    CC_INCREMENT_GL_DRAWS(1);
    CC_PROFILER_STOP_CATEGORY(kCCProfilerCategorySprite, @"BuildingsLayer - draw");
}

- (void)dealloc {

    glDeleteVertexArrays( 2, &buildingsVertexObject[0] );
    glDeleteVertexArrays( 1, &windowsVertexObject );
    glDeleteBuffers( 1, &buildingsVertexBuffer );
    glDeleteBuffers( 1, &buildingsIndicesBuffer );
    glDeleteBuffers( 1, &windowsVertexBuffer );
    glDeleteBuffers( 1, &windowsIndicesBuffer );
    buildingsVertexBuffer = 0;
    buildingsIndicesBuffer = 0;
    windowsVertexBuffer = 0;
    windowsIndicesBuffer = 0;
    CHECK_GL_ERROR_DEBUG();
}

@end
