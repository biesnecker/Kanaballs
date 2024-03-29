/*********************************************************************
 *	
 *	Space Manager
 *
 *	SpaceManager.m
 *
 *	Manage the space for the application
 *
 *	http://www.mobile-bros.com
 *
 *	Created by Robert Blackwood on 02/22/2009.
 *	Copyright 2009 Mobile Bros. All rights reserved.
 *
 **********************************************************************/

#import "SpaceManager.h"

void defaultEachShape(void *ptr, void* data)
{
	cpShape *shape = (cpShape*) ptr;

#ifdef _SPACE_MANAGER_FOR_COCOS2D	
	CocosNode *node = shape->data;
	if(node) 
	{
		cpBody *body = shape->body;
		[node setPosition: cpv( body->p.x, body->p.y)];
		[node setRotation: CC_RADIANS_TO_DEGREES( -body->a )];
	}
#endif
	//do nothing.... idk
}

#ifdef _SPACE_MANAGER_FOR_COCOS2D
static void eachShapeAsChildren(void *ptr, void* data)
{
	cpShape *shape = (cpShape*) ptr;
	
	CocosNode *node = shape->data;
	if(node) 
	{
		cpBody *body = shape->body;
		CocosNode *parent = node.parent;
		if (parent)
		{
			[node setPosition:[node.parent convertToNodeSpace:body->p]];
			
			cpVect zPt = [node convertToWorldSpace:cpvzero];
			cpVect dPt = [node convertToWorldSpace:cpvforangle(body->a)];
			cpVect rPt = cpvsub(dPt,zPt);
			float angle = cpvtoangle(rPt);
			[node setRotation: CC_RADIANS_TO_DEGREES(-angle)];
		}
		else
		{
			[node setPosition:body->p];
			[node setRotation: CC_RADIANS_TO_DEGREES( -body->a )];
		}
	}
}
#endif

static int collHandleInvocations(cpShape *a, cpShape *b, cpContact *contacts, int numContacts, cpFloat normal_coef, void *data)
{
	NSInvocation *invocation = (NSInvocation*)data;
	
	@try {
		[invocation setArgument:&a atIndex:2];
		[invocation setArgument:&b atIndex:3];
		[invocation setArgument:&contacts atIndex:4];
		[invocation setArgument:&numContacts atIndex:5];
		[invocation setArgument:&normal_coef atIndex:6];
	}
	@catch (NSException *e) {
		//No biggie, continue!
	}
	
	[invocation invoke];
	
	BOOL retVal;
	[invocation getReturnValue:&retVal];
	
	return retVal;
}

static int collIgnore(cpShape *a, cpShape *b, cpContact *contacts, int numContacts, cpFloat normal_coef, void *data)
{
	return 0;
}

static void collectAllShapes(cpShape *shape, NSMutableArray *outShapes)
{
	[outShapes addObject:[NSValue valueWithPointer:shape]];
}

static void updateBBCache(cpShape *shape, void *unused)
{
	cpShapeCacheBB(shape);
}

/* Private Method Declarations */
@interface SpaceManager (PrivateMethods)
-(void) setupDefaultShape:(cpShape*) s;
-(void) freeShapes;
-(void) removeShapes;

-(NSString*) writeShape:(cpShape*)shape;
-(NSString*) writeConstraint:(cpConstraint*)shape;
@end

@implementation SpaceManager

@synthesize space = _space;
@synthesize topWall,bottomWall,rightWall,leftWall;
@synthesize steps = _steps;
@synthesize lastDt = _lastDt;
@synthesize iterateStatic = _iterateStatic;
@synthesize rehashStaticEveryStep = _rehashStaticEveryStep;
@synthesize iterateFunc = _iterateFunc;
@synthesize staticBody = _staticBody;
@synthesize constantDt = _constantDt;
@synthesize cleanupBodyDependencies = _cleanupBodyDependencies;
//gravity and damping are written out manually

-(id) init
{
	return [self initWithSize:20 count:50];
}

-(id) initWithSize:(int)size count:(int)count
{
	id this = [self initWithSpace:cpSpaceNew()];
	
	cpSpaceResizeStaticHash(_space, size, count);
	cpSpaceResizeActiveHash(_space, size, count);
	
	return this;
}

-(id) initWithSpace:(cpSpace*)space
{	
	[super init];
		
	cpInitChipmunk();
	
	_space = space;
	
	_space->gravity = cpv(0, -9.8*10);
	_space->elasticIterations = _space->iterations;
	topWall = bottomWall = rightWall = leftWall = nil;
	_staticBody = cpBodyNew(STATIC_MASS, INFINITY);
	_steps = 2;
	_iterateStatic = YES;
	_rehashStaticEveryStep = NO;
	_rehashNextStep = NO;
	_cleanupBodyDependencies = YES;
	_constantDt = 0.0;
	
	_iterateFunc = &defaultEachShape;
	_freeShapes = [[NSMutableArray alloc] init];
	_removedShapes = [[NSMutableArray alloc] init];
	_invocations = [[NSMutableArray alloc] init];
	
	return self;
}

-(void) dealloc
{	
	if (_space != nil)
	{
		cpSpaceFreeChildren(_space);
		cpSpaceFree(_space);
	}	
	
	[_freeShapes release];
	[_removedShapes release];
	[_invocations release];
	
	[super dealloc];
}

- (void) loadSpaceFromFile:(NSString*)file
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *dataPath = [[paths objectAtIndex:0] stringByAppendingPathComponent:file];
	
	[self loadSpaceFromPath:dataPath];
}

- (void) saveSpaceToFile:(NSString*)file
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *dataPath = [[paths objectAtIndex:0] stringByAppendingPathComponent:file];	
	
	[self saveSpaceToPath:dataPath];
}

- (void) loadSpaceFromPath:(NSString*)path
{
	if ([[NSFileManager defaultManager] fileExistsAtPath:path])
	{
		
	}
}

- (void) saveSpaceToPath:(NSString*)path
{
	if (![[NSFileManager defaultManager] fileExistsAtPath:path])
	{
		//ERROR
	}
	
	NSMutableString *fileContents = [NSMutableString stringWithString:@"<?xml version=""1.0"" encoding=""UTF-8""?>"];
	[fileContents appendString:@"\n<space>"];
	
	//Write out active shapes
	cpHashSet *activeSet = _space->activeShapes->handleSet;
	for(int i=0; i<activeSet->size; i++)
	{
		cpHashSetBin *bin = activeSet->table[i];
		while(bin)
		{
			cpHashSetBin *next = bin->next;
			cpShape *shape = (cpShape*)bin->elt;
			[fileContents appendString:[self writeShape:shape]];
			bin = next;
		}
	}
	
	//Write out static shapes
	cpHashSet *staticSet = _space->staticShapes->handleSet;
	for(int i=0; i<staticSet->size; i++)
	{
		cpHashSetBin *bin = staticSet->table[i];
		while(bin)
		{
			cpHashSetBin *next = bin->next;
			cpShape *shape = (cpShape*)bin->elt;
			[fileContents appendString:[self writeShape:shape]];
			bin = next;
		}
	}
	
	//Write out constraints
	for(int i=0; i<_space->constraints->num; i++)
	{
		cpConstraint *constraint = (cpConstraint *)_space->constraints->arr[i];
		[fileContents appendString:[self writeConstraint:constraint]];
	}
	
	[fileContents appendString:@"\n</space>"];
	
	[[NSFileManager defaultManager] createFileAtPath:path 
											contents:[fileContents dataUsingEncoding:NSUTF8StringEncoding]
										  attributes:nil];
}

-(NSString*) writeShape:(cpShape*)shape
{
	return [NSString stringWithFormat:@"\n<shape/>"];
}

-(NSString*) writeConstraint:(cpConstraint*)constraint
{
	return [NSString stringWithFormat:@"\n<constraint/>"];
}

-(void) setGravity:(cpVect)gravity
{
	_space->gravity = gravity;
}

-(cpVect) gravity
{
	return _space->gravity;
}

-(void) setDamping:(cpFloat)damping
{
	_space->damping = damping;
}

-(cpFloat) damping
{
	return _space->damping;
}

#ifdef _SPACE_MANAGER_FOR_COCOS2D
-(void) start:(ccTime)dt
{
	_timer = [Timer timerWithTarget:self selector:@selector(step:) interval:dt];
	[[Scheduler sharedScheduler] scheduleTimer:_timer];
}

-(void) start
{
	[self start:0];
}

-(void) stop
{
	[[Scheduler sharedScheduler] unscheduleTimer:_timer];
	_timer = nil;
}

-(void) addWindowContainmentWithFriction:(cpFloat)friction elasticity:(cpFloat)elasticity inset:(cpVect)inset
{
	CGSize  wins = [[Director sharedDirector] winSize];
	
	// bottom
	bottomWall = cpSegmentShapeNew(_staticBody, cpv(inset.x,inset.y), cpv(wins.width-inset.x,inset.y), 1.0f);
	bottomWall->e = elasticity; 
	bottomWall->u = friction;
	cpSpaceAddStaticShape(_space, bottomWall);
	
	// top
	topWall = cpSegmentShapeNew(_staticBody, cpv(inset.x,wins.height-inset.y), cpv(wins.width-inset.x,wins.height-inset.y), 1.0f);
	topWall->e = elasticity; 
	topWall->u = friction;
	cpSpaceAddStaticShape(_space, topWall);
	
	// left
	leftWall = cpSegmentShapeNew(_staticBody, cpv(inset.x,inset.y), cpv(inset.x,wins.height-inset.y), 1.0f);
	leftWall->e = elasticity; 
	leftWall->u = friction;
	cpSpaceAddStaticShape(_space, leftWall);
	
	// right
	rightWall = cpSegmentShapeNew(_staticBody, cpv(wins.width-inset.x,inset.y), cpv(wins.width-inset.x,wins.height-inset.y), 1.0f);
	rightWall->e = elasticity; 
	rightWall->u = friction;
	cpSpaceAddStaticShape(_space, rightWall);
}

#endif

-(void) step: (cpFloat) delta
{
	if (_constantDt)
		_lastDt = _constantDt/_steps;
	else
		_lastDt = delta/(cpFloat)_steps;
	
	//re-calculate static shape positions if this is set
	if (_rehashStaticEveryStep || _rehashNextStep)
	{
		cpSpaceRehashStatic(_space);
		_rehashNextStep = NO;
	}
	
	//for the iterations given
	for(int i=0; i<_steps; i++)
		cpSpaceStep(_space, _lastDt);
	
	cpSpaceHashEach(_space->activeShapes, _iterateFunc, self);

	//Since static shapes are stationary, you do not really need this (only for the first sync)
	if (_iterateStatic)
		cpSpaceHashEach(_space->staticShapes, _iterateFunc, self);	
	
	//cleanup
	[self freeShapes];
	[self removeShapes];
}


-(void) scheduleToRemoveShape:(cpShape*)shape
{
	if (shape != nil)
	{
		//NSArray's like NSObjects
		NSValue *nsv = [NSValue valueWithPointer:shape];
		[_removedShapes addObject:nsv];
	}
}

-(void) removeShapes
{
	cpShape* shape;
	int count = [_removedShapes count];
	
	for (int i = 0; i < count; i++)
	{
		shape = (cpShape*)[[_removedShapes objectAtIndex:i] pointerValue];
		[self removeShape:shape];
	}
}

-(void) freeShapes
{
	cpShape* shape;
	int count = [_freeShapes count];
	
	for (int i = 0; i < count; i++)
	{
		shape = (cpShape*)[[_freeShapes objectAtIndex:i] pointerValue];
		[self removeAndFreeShape:shape];
	}
	
	[_freeShapes removeAllObjects];
}

-(void) removeAndFreeShape:(cpShape*)shape
{
	if (_cleanupBodyDependencies)
		[self removeAndFreeConstraintsOnBody:shape->body];
	
	[self removeShape:shape];
	cpBodyFree(shape->body);
	cpShapeFree(shape);	
	
	if (_cleanupBodyDependencies)
		[self removeAndFreeConstraintsOnBody:shape->body];
}

-(cpShape*) removeShape:(cpShape*) shape
{
	if (shape->body->m == STATIC_MASS)
	{	
		//Static Bodies are not added (assumption)
		//cpSpaceRemoveBody(space, shape->body);
		cpSpaceRemoveStaticShape(_space, shape);
	}
	else
	{
		cpSpaceRemoveBody(_space, shape->body);
		cpSpaceRemoveShape(_space, shape);
	}
	
	return shape;
}

-(void) scheduleToRemoveAndFreeShape:(cpShape*)shape
{
	if (shape != nil)
	{
		//NSArray's like NSObjects
		NSValue *nsv = [NSValue valueWithPointer:shape];
		[_freeShapes addObject:nsv];
	}
}

-(void) setupDefaultShape:(cpShape*) s
{
	//Remember to set these later, if you want different values
	s->e = .5; 
	s->u = .5;
	s->collision_type = 0;
	s->data = nil;
}

-(cpShape*) addCircleAt:(cpVect)pos mass:(cpFloat)mass radius:(cpFloat)radius
{
	cpShape* shape;
	cpFloat moment = STATIC_MASS;
	
	if (mass != STATIC_MASS)
		moment = cpMomentForCircle(mass, radius, radius, cpvzero);
	
	shape = cpCircleShapeNew(cpBodyNew(mass, moment), radius, cpvzero);
	shape->body->p = pos;
	
	[self setupDefaultShape:shape];
	[self addShape:shape];
	
	return shape;
}

-(cpShape*) addRectAt:(cpVect)pos mass:(cpFloat)mass width:(cpFloat)width height:(cpFloat)height rotation:(cpFloat)r 
{	
	return [self addPolyAt:pos mass:mass rotation:r numPoints:4 points:		
																		cpv(-width/2.0f,-height/2.0f),	/* bottom-left */
																		cpv(-width/2.0f, height/2.0f),	/* top-left */ 
																		cpv( width/2.0f, height/2.0f),	/* top-right */
																		cpv( width/2.0f,-height/2.0f)];	/* bottom-right */
}

-(cpShape*) addPolyAt:(cpVect)pos mass:(cpFloat)mass rotation:(cpFloat)r numPoints:(int)numPoints points:(cpVect)pt, ...
{
	cpShape* shape = nil;
	
	if (numPoints >= 3)
	{
		va_list args;
		va_start(args,pt);

		//Setup our vertices
		cpVect *verts = malloc(sizeof(cpVect)*numPoints);
		verts[0] = pt;
		for (int i = 1; i < numPoints; i++)
			verts[i] = va_arg(args, cpVect);
		
		//Setup our poly shape
		cpFloat moment = STATIC_MASS;
		if (mass != STATIC_MASS)
			moment = cpMomentForPoly(mass, numPoints, verts, cpvzero);
		
		shape = cpPolyShapeNew(cpBodyNew(mass, moment), numPoints, verts, cpvzero);
		shape->body->p = pos;
		
		[self setupDefaultShape:shape];
		cpBodySetAngle(shape->body, r);	
		[self addShape:shape];
			
		free(verts);
		va_end(args);
	}
	
	return shape;
}

-(cpShape*) addSegmentAtWorldAnchor:(cpVect)fromPos toWorldAnchor:(cpVect)toPos mass:(cpFloat)mass radius:(cpFloat)radius;
{
	cpVect pos = cpvmult(cpvsub(toPos,fromPos), .5);
	return [self addSegmentAt:cpvadd(fromPos,pos) fromLocalAnchor:cpvmult(pos,-1) toLocalAnchor:pos mass:mass radius:radius];
}

-(cpShape*) addSegmentAt:(cpVect)pos fromLocalAnchor:(cpVect)fromPos toLocalAnchor:(cpVect)toPos mass:(cpFloat)mass radius:(cpFloat)radius
{
	cpShape* shape;
	cpFloat moment = STATIC_MASS;
	
	if (mass != STATIC_MASS)
		moment = cpMomentForSegment(mass, fromPos, toPos);
	
	shape = cpSegmentShapeNew(cpBodyNew(mass, moment), fromPos, toPos, radius);
	shape->body->p = pos;
	
	[self setupDefaultShape:shape];
	[self addShape:shape];
	
	return shape;
}

-(cpShape*) getShapeAt:(cpVect)pos layers:(cpLayers)layers group:(cpLayers)group
{
	return cpSpacePointQueryFirst(_space, pos, layers, group);
}

-(cpShape*) getShapeAt:(cpVect)pos
{
	return [self getShapeAt:pos layers:-1 group:0];
}

-(void) rehashActiveShapes
{
	cpSpaceHashEach(_space->activeShapes, (cpSpaceHashIterator)&updateBBCache, NULL);
	cpSpaceHashRehash(_space->activeShapes);
}

-(void) rehashStaticShapes
{
	cpSpaceRehashStatic(_space);
}

-(void) rehashStaticShape:(cpShape*)shape
{
	_rehashNextStep = YES;
	//NEEDS WORK, slows down simulation
	//cpSpaceHashRemove(_space->staticShapes, shape, shape->id);
	////shapeRemovalArbiterReject(_space, shape); //I don't think this is necessary
	//cpShapeCacheBB(shape);
	//cpSpaceHashInsert(_space->staticShapes, shape, shape->id, shape->bb);
}

-(NSArray*) getShapesAt:(cpVect)pos layers:(cpLayers)layers group:(cpLayers)group
{
	NSMutableArray *shapes = [[[NSMutableArray alloc] init] autorelease];
	cpSpacePointQuery(_space, pos, layers, group, (cpSpacePointQueryFunc)collectAllShapes, shapes);
		
	return shapes;
}

-(NSArray*) getShapesAt:(cpVect)pos
{
	return [self getShapesAt:pos layers:0 group:0];
}

-(BOOL) isPersistentContactOnShape:(cpShape*)shape contactShape:(cpShape*)shape2
{
	cpShape *shape_pair[] = {shape, shape2};
	int max_contact_staleness = cp_contact_persistence;
	
	//Try and find the the persistent contact
	cpArbiter *arb = (cpArbiter *)cpHashSetFind(_space->contactSet, CP_HASH_PAIR(shape, shape2), shape_pair);
	
	//check the freshness, chipmunk keeps them around for cp_contact_persistence "3" times
	return (arb && _space->stamp - arb->stamp < max_contact_staleness);
}

-(cpShape*) persistentContactOnShape:(cpShape*)shape;
{
	cpShape *contactShape = NULL;
	int max_contact_staleness = cp_contact_persistence;
	cpHashSet *contactSet = _space->contactSet;
	for(int i=0; i<contactSet->size && !contactShape; i++)
	{
		cpHashSetBin *bin = contactSet->table[i];
		while(bin && !contactShape)
		{
			cpHashSetBin *next = bin->next;
			cpArbiter *arb = (cpArbiter *)bin->elt;
			
			if (arb && (arb->a == shape || arb->b == shape))
			{	
				if(_space->stamp - arb->stamp < max_contact_staleness)
					contactShape = (arb->a == shape) ? arb->b : arb->a;
			}
			
			bin = next;
		}
	}
	
	return contactShape;
}

-(NSArray*) getConstraints
{
	NSMutableArray *constraints = [[[NSMutableArray alloc] init] autorelease];
	int num = _space->constraints->num;
	
	for (int i = 0; i < num; i++)
		[constraints addObject:[NSValue valueWithPointer:_space->constraints->arr[i]]];
	
	return constraints;
}

-(NSArray*) getConstraintsOnBody:(cpBody*)body
{
	NSMutableArray *constraints = [[[NSMutableArray alloc] init] autorelease];
	cpConstraint* constraint;
	int num = _space->constraints->num;
	
	for (int i = 0; i < num; i++)
	{
		constraint = _space->constraints->arr[i];
		
		if (body == constraint->a || body == constraint->b)
			[constraints addObject:[NSValue valueWithPointer:constraint]];
	}
	
	return constraints;
}

-(void) addShape:(cpShape*)shape
{
	if (shape->body->m != STATIC_MASS)
	{
		cpSpaceAddBody(_space, shape->body);
		cpSpaceAddShape(_space, shape);
	}
	else
		cpSpaceAddStaticShape(_space, shape);
}

-(cpShape*) morphShapeToStatic:(cpShape*)shape
{
	return [self morphShapeToActive:shape mass:STATIC_MASS];
}

-(cpShape*) morphShapeToActive:(cpShape*)shape mass:(cpFloat)mass
{
	[self removeShape:shape];
	cpBodySetMass(shape->body, mass);
	[self addShape:shape];
	
	return shape;
}

-(cpConstraint*) removeConstraint:(cpConstraint*)constraint
{
	cpSpaceRemoveConstraint(_space, constraint);	
	return constraint;
}

-(void) removeAndFreeConstraint:(cpConstraint*)constraint
{
	[self removeConstraint:constraint];
	cpConstraintFree(constraint);
}

-(void) removeAndFreeConstraintsOnBody:(cpBody*)body
{
	cpConstraint *constraint;
	cpArray *array = _space->constraints;

	for (int i = 0; i < array->num; i++)
	{
		constraint = array->arr[i];
			
		if (body == constraint->a || body == constraint->b)
		{
			//Need a callback prob for about to delete constraint
			//reason: it's the only thing that may be deleted arbitrarily
			//because of the cleanupBodyDependencies
			
			//more efficient to use this method of deletion
			cpArrayDeleteIndex(array, i);
			cpConstraintFree(constraint);
			i--;
		}
	}
}

-(cpConstraint*) addSpringToBody:(cpBody*)toBody fromBody:(cpBody*)fromBody toBodyAnchor:(cpVect)anchr1 fromBodyAnchor:(cpVect)anchr2 restLength:(cpFloat)rest stiffness:(cpFloat)stiff damping:(cpFloat)damp
{
	cpConstraint *spring = cpDampedSpringNew(toBody, fromBody, anchr1, anchr2, rest, stiff, damp);
	return cpSpaceAddConstraint(_space, spring);
}

-(cpConstraint*) addSpringToBody:(cpBody*)toBody fromBody:(cpBody*)fromBody restLength:(cpFloat)rest stiffness:(cpFloat)stiff damping:(cpFloat)damp
{
	return [self addSpringToBody:toBody fromBody:fromBody toBodyAnchor:cpvzero fromBodyAnchor:cpvzero restLength:rest stiffness:stiff damping:damp];
}

-(cpConstraint*) addSpringToBody:(cpBody*)toBody fromBody:(cpBody*)fromBody stiffness:(cpFloat)stiff
{
	cpFloat m1 = toBody->m;
	cpFloat m2 = fromBody->m;
	
	return [self addSpringToBody:toBody fromBody:fromBody restLength:0.0 stiffness:((m1 < m2) ? m1 : m2) damping:0.0];
}

-(cpConstraint*) addGrooveToBody:(cpBody*)toBody fromBody:(cpBody*)fromBody grooveAnchor1:(cpVect)groove1 grooveAnchor2:(cpVect)groove2 fromBodyAnchor:(cpVect)anchor2
{
	cpConstraint *groove = cpGrooveJointNew(toBody, fromBody, groove1, groove2, anchor2);
	return cpSpaceAddConstraint(_space, groove);
}

-(cpConstraint*) addGrooveToBody:(cpBody*)toBody fromBody:(cpBody*)fromBody grooveLength:(cpFloat)length isHorizontal:(bool)horiz fromBodyAnchor:(cpVect)anchor2
{
	cpVect diff = cpvzero;
	
	if (horiz)
		diff = cpv(length/2.0,0.0);
	else
		diff = cpv(0.0,length/2.0);
	
	return [self addGrooveToBody:toBody fromBody:fromBody grooveAnchor1:cpvsub(toBody->p, diff) grooveAnchor2:cpvadd(toBody->p, diff) fromBodyAnchor:anchor2];
}

-(cpConstraint*) addGrooveToBody:(cpBody*)toBody fromBody:(cpBody*)fromBody grooveLength:(cpFloat)length isHorizontal:(bool)horiz
{
	return [self addGrooveToBody:toBody fromBody:fromBody grooveLength:length isHorizontal:horiz fromBodyAnchor:cpvzero];
}

-(cpConstraint*) addSlideToBody:(cpBody*)toBody fromBody:(cpBody*)fromBody toBodyAnchor:(cpVect)anchr1 fromBodyAnchor:(cpVect)anchr2 minLength:(cpFloat)min maxLength:(cpFloat)max;
{	
	cpConstraint *slide = cpSlideJointNew(toBody, fromBody, anchr1, anchr2, min, max);
	return cpSpaceAddConstraint(_space, slide);
}

-(cpConstraint*) addSlideToBody:(cpBody*)toBody fromBody:(cpBody*)fromBody minLength:(cpFloat)min maxLength:(cpFloat)max
{
	return [self addSlideToBody:toBody fromBody:fromBody toBodyAnchor:cpvzero fromBodyAnchor:cpvzero minLength:min maxLength:max];
}

-(cpConstraint*) addPinToBody:(cpBody*)toBody fromBody:(cpBody*)fromBody toBodyAnchor:(cpVect)anchr1 fromBodyAnchor:(cpVect)anchr2
{
	cpConstraint *pin = cpPinJointNew(toBody, fromBody, anchr1, anchr2);
	return cpSpaceAddConstraint(_space, pin);
}

-(cpConstraint*) addPinToBody:(cpBody*)toBody fromBody:(cpBody*)fromBody
{
	return [self addPinToBody:toBody fromBody:fromBody toBodyAnchor:cpvzero fromBodyAnchor:cpvzero];
}

-(cpConstraint*) addPivotToBody:(cpBody*)toBody fromBody:(cpBody*)fromBody toBodyAnchor:(cpVect)anchr1 fromBodyAnchor:(cpVect)anchr2
{
	cpConstraint *pin = cpPivotJointNew2(toBody, fromBody, anchr1, anchr2);
	return cpSpaceAddConstraint(_space, pin);
}

-(cpConstraint*) addPivotToBody:(cpBody*)toBody fromBody:(cpBody*)fromBody worldAnchor:(cpVect)anchr
{
	cpConstraint *pin = cpPivotJointNew(toBody, fromBody, anchr);
	return cpSpaceAddConstraint(_space, pin);	
}

-(cpConstraint*) addPivotToBody:(cpBody*)toBody fromBody:(cpBody*)fromBody
{
	return [self addPivotToBody:toBody fromBody:fromBody toBodyAnchor:cpvzero fromBodyAnchor:cpvzero];
}

-(cpConstraint*) addMotorToBody:(cpBody*)toBody fromBody:(cpBody*)fromBody rate:(cpFloat)rate
{
	cpConstraint *motor = cpSimpleMotorNew(toBody, fromBody, rate);
	return cpSpaceAddConstraint(_space, motor);
}

-(cpConstraint*) addMotorToBody:(cpBody*)toBody rate:(cpFloat)rate
{
	return [self addMotorToBody:toBody fromBody:_staticBody rate:rate];
}

-(cpConstraint*) addGearToBody:(cpBody*)toBody fromBody:(cpBody*)fromBody phase:(cpFloat)phase ratio:(cpFloat)ratio
{
	cpConstraint *gear = cpGearJointNew(toBody, fromBody, phase, ratio);
	return cpSpaceAddConstraint(_space, gear);
}

-(cpConstraint*) addGearToBody:(cpBody*)toBody fromBody:(cpBody*)fromBody ratio:(cpFloat)ratio
{
	return [self addGearToBody:toBody fromBody:fromBody phase:0.0 ratio:ratio];
}

-(cpConstraint*) addBreakableToConstraint:(cpConstraint*)breakConstraint maxForce:(cpFloat)max
{
	cpConstraint *breakable = cpBreakableJointNew(breakConstraint, _space);
	breakable->maxForce = max;
	return cpSpaceAddConstraint(_space, breakable);
}

-(cpConstraint*) addRotaryLimitToBody:(cpBody*)toBody fromBody:(cpBody*)fromBody min:(cpFloat)min max:(cpFloat)max
{
	cpConstraint* rotaryLimit = cpRotaryLimitJointNew(toBody, fromBody, min, max);
	return cpSpaceAddConstraint(_space, rotaryLimit);
}

-(cpConstraint*) addRotaryLimitToBody:(cpBody*)toBody min:(cpFloat)min max:(cpFloat)max
{
	return [self addRotaryLimitToBody:toBody fromBody:_staticBody min:min max:max];
}

-(cpConstraint*) addRatchetToBody:(cpBody*)toBody fromBody:(cpBody*)fromBody direction:(cpFloat)direction
{
	cpConstraint *rachet = cpRatchetJointNew(toBody, fromBody, direction);
	return cpSpaceAddConstraint(_space, rachet);
}

-(cpConstraint*) addRatchetToBody:(cpBody*)toBody direction:(cpFloat)direction
{
	return [self addRatchetToBody:toBody fromBody:_staticBody direction:direction];
}

-(void) ignoreCollionBetweenType:(unsigned int)type1 otherType:(unsigned int)type2
{
	cpSpaceAddCollisionPairFunc(_space, type1, type2, &collIgnore, NULL);
}

-(cpConstraint*) addRotarySpringToBody:(cpBody*)toBody fromBody:(cpBody*)fromBody restAngle:(cpFloat)restAngle stiffness:(cpFloat)stiff damping:(cpFloat)damp
{
	cpConstraint* rotarySpring = cpDampedRotarySpringNew(toBody, fromBody, restAngle, stiff, damp);
	return cpSpaceAddConstraint(_space, rotarySpring);
}

-(cpConstraint*) addRotarySpringToBody:(cpBody*)toBody restAngle:(cpFloat)restAngle stiffness:(cpFloat)stiff damping:(cpFloat)damp
{
	return [self addRotarySpringToBody:toBody fromBody:_staticBody restAngle:restAngle stiffness:stiff damping:damp];
}

-(void) addCollisionCallbackBetweenType:(unsigned int)type1 otherType:(unsigned int) type2 target:(id)target selector:(SEL)selector
{
	//set up the invocation
	NSMethodSignature * sig = [[target class] instanceMethodSignatureForSelector:selector];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:sig];
	
	[invocation setTarget:target];
	[invocation setSelector:selector];
	
	//add the callback to chipmunk
	cpSpaceAddCollisionPairFunc(_space, type1, type2, &collHandleInvocations, invocation);
	
	//we'll keep a ref so it won't disappear, prob could just retain and clear hash later
	[_invocations addObject:invocation];
}

-(void) removeCollisionCallbackBetweenType:(unsigned int)type1 otherType:(unsigned int)type2
{
	//Chipmunk hashes the invocation for us, we must pull it out
	unsigned int ids[] = {type1, type2};
	unsigned int hash = CP_HASH_PAIR(type1, type2);
	cpCollPairFunc *pair = cpHashSetFind(_space->collFuncSet, hash, ids);
	
	//delete the invocation, if there is one (invoke can be null)
	if (pair != NULL)
	{
		id invoke = pair->data;
		[_invocations removeObject:invoke];
	}

	//Remove the collision callback
	cpCollPairFunc *old_pair = (cpCollPairFunc *)cpHashSetRemove(_space->collFuncSet, hash, ids);
	free(old_pair);	
}

@end
