/*********************************************************************
 *	
 *	cpConstraintNode
 *
 *	cpConstraintNode.m
 *
 *	Provide Drawing for Constraints
 *
 *	http://www.mobile-bros.com
 *
 *	Created by Robert Blackwood on 02/22/2009.
 *	Copyright 2009 Mobile Bros. All rights reserved.
 *
 **********************************************************************/

#import <OpenGLES/ES1/gl.h>
#import "cpConstraintNode.h"
#import "DrawingPrimitives.h"


@interface cpConstraintNode(PrivateMethods)
- (void) drawPinJoint:(cpPinJoint*)joint bodyA:(cpBody*)body_a bodyB:(cpBody*)body_b;
- (void) drawSlideJoint:(cpSlideJoint*)joint bodyA:(cpBody*)body_a bodyB:(cpBody*)body_b;
- (void) drawPivotJoint:(cpPivotJoint*)joint bodyA:(cpBody*)body_a bodyB:(cpBody*)body_b;
- (void) drawGrooveJoint:(cpGrooveJoint*)joint bodyA:(cpBody*)body_a bodyB:(cpBody*)body_b;
- (void) drawSpringJoint:(cpDampedSpring*)joint bodyA:(cpBody*)body_a bodyB:(cpBody*)body_b;
- (void) drawBreakableJoint:(cpBreakableJoint*)joint bodyA:(cpBody*)body_a bodyB:(cpBody*)body_b;
- (void) drawMotorJoint:(cpSimpleMotor*)joint bodyA:(cpBody*)body_a bodyB:(cpBody*)body_b;
- (void) drawGearJoint:(cpGearJoint*)joint bodyA:(cpBody*)body_a bodyB:(cpBody*)body_b;

- (BOOL) containsPoint:(cpVect)pt padding:(cpFloat)padding constraint:(cpConstraint*)constraint;
@end

@implementation cpConstraintNode

@synthesize constraint = _constraint;
@synthesize color = _color;
@synthesize opacity = _opacity;
@synthesize pointSize = _pointSize;
@synthesize lineWidth = _lineWidth;
@synthesize smoothDraw = _smoothDraw;
@synthesize autoFreeConstraint = _autoFreeConstraint;
@synthesize spaceManager = _spaceManager;

+ (id) nodeWithConstraint:(cpConstraint*)c
{
	return [[[self alloc] initWithConstraint:c] autorelease];
}

- (id) initWithConstraint:(cpConstraint*)c
{
	[super init];
	
	_constraint = c;
	_color = ccBLACK;
	_opacity = 255;
	_pointSize = 3;
	_lineWidth = 1;
	_smoothDraw = YES;
	_constraint->data = self;
	
	return self;
}

- (void) dealloc
{
	if (_autoFreeConstraint)
		[_spaceManager removeConstraint:_constraint];
	[super dealloc];
}

- (BOOL) containsPoint:(cpVect)pt padding:(cpFloat)padding
{
	return [self containsPoint:pt padding:padding constraint:_constraint];
}

- (BOOL) containsPoint:(cpVect)pt padding:(cpFloat)padding constraint:(cpConstraint*)constraint
{
	BOOL contains = NO;
	cpBody *body_a = constraint->a;
	cpBody *body_b = constraint->b;
	
	cpVect apt, bpt;
	
	const cpConstraintClass *klass = constraint->klass;
	
	if(klass == cpPinJointGetClass())
	{
		cpPinJoint *joint = (cpPinJoint*)constraint;
		
		apt = cpBodyLocal2World(body_a, joint->anchr1);
		bpt = cpBodyLocal2World(body_b, joint->anchr2);
	}
	else if(klass == cpSlideJointGetClass())
	{
		cpSlideJoint *joint = (cpSlideJoint*)constraint;
		
		apt = cpBodyLocal2World(body_a, joint->anchr1);
		bpt = cpBodyLocal2World(body_b, joint->anchr2);
	}
	else if(klass == cpPivotJointGetClass())
	{
		cpPivotJoint* joint = (cpPivotJoint*)constraint;
		
		apt = cpBodyLocal2World(body_a, joint->anchr1);
		bpt = cpBodyLocal2World(body_b, joint->anchr2);
	}
	else if(klass == cpGrooveJointGetClass())
	{
		cpGrooveJoint *joint = (cpGrooveJoint*)constraint;
		
		apt = cpBodyLocal2World(body_a, joint->grv_a);
		bpt = cpBodyLocal2World(body_a, joint->grv_b);
	}
	else if(klass == cpBreakableJointGetClass())
	{
		//This works... but it uses the assumption that data is a cpConstraintNode
		cpBreakableJoint *joint = (cpBreakableJoint*)constraint;
		return [(cpConstraintNode*)joint->delegate->data containsPoint:pt padding:padding constraint:joint->delegate];
	}
	else if (klass == cpSimpleMotorGetClass())
	{
		apt = bpt = body_a->p;
	}
	else if (klass == cpGearJointGetClass())
	{
		cpGearJoint *joint = (cpGearJoint*)constraint;
		
		cpFloat ratio = joint->ratio;
		
		cpFloat radius1 = 5.0 / ratio;
		cpFloat radius2 = 5.0 * ratio;

		// pad it out by radius (half diameter as the biggest gear...)
		padding += (radius1 > radius2) ? radius1 : radius2;
		
		apt = body_a->p;
		bpt = body_b->p;
	}
	else if(klass == cpDampedSpringGetClass())
	{
		padding += 20; // 20 is width of spring
		cpDampedSpring *joint = (cpDampedSpring*)constraint;
		
		apt = cpBodyLocal2World(body_a, joint->anchr1);
		bpt = cpBodyLocal2World(body_b, joint->anchr2);
	}
	else
		return NO;
		
	cpFloat width = (_pointSize > _lineWidth) ? _pointSize : _lineWidth;
	width += padding*2;
	
	cpFloat length = cpvlength(cpvsub(bpt, apt)) + padding*2;
	cpVect halfpt = cpvadd(body_a->p, cpvmult(cpvsub(bpt, apt), 0.5f));
	
	/* Algorithm Explained
	 
		At this point we have 2 pts (in some cases they are the same point).
		From these two points we construct a flat (rotation zero) rectangle, we
		then rotate the point in question by the same rotation it would take to make 
		the actual bounding rect "flat". Rotation is always around the center (halfpt)
		of the rect.
	 */
	
	float dx = apt.x - bpt.x;
	float dy = apt.y - bpt.y;
	float rotation = atan2f(dy,dx);	
		
	//recalc pt (non-rotated)
	pt = cpvadd(halfpt, cpvrotate(cpvsub(pt,halfpt), cpvforangle(-rotation)));
	
	contains = CGRectContainsPoint(CGRectMake(halfpt.x-length/2.0, halfpt.y-width/2.0, length, width), CGPointMake(pt.x,pt.y));
	
	return contains;
}

-(void)draw
{
	[super draw];

	glColor4ub(_color.r, _color.g, _color.b, _opacity);
	glPointSize(_pointSize);
	glLineWidth(_lineWidth);
	if (_smoothDraw && _lineWidth <= 1) //OpelGL ES doesn't support smooth lineWidths > 1
	{
		glEnable(GL_LINE_SMOOTH);
		glEnable(GL_POINT_SMOOTH);
	}
	else
	{
		glDisable(GL_LINE_SMOOTH);
		glDisable(GL_POINT_SMOOTH);
	}
	
	if( _opacity != 255 )
		glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	
	cpBody *body_a = _constraint->a;
	cpBody *body_b = _constraint->b;
	
	const cpConstraintClass *klass = _constraint->klass;
		
	if(klass == cpPinJointGetClass())
		[self drawPinJoint:(cpPinJoint*)_constraint bodyA:body_a bodyB:body_b]; 
	else if(klass == cpSlideJointGetClass())
		[self drawSlideJoint:(cpSlideJoint*)_constraint bodyA:body_a bodyB:body_b]; 
	else if(klass == cpPivotJointGetClass())
		[self drawPivotJoint:(cpPivotJoint*)_constraint bodyA:body_a bodyB:body_b];
	else if(klass == cpGrooveJointGetClass())
		[self drawGrooveJoint:(cpGrooveJoint*)_constraint bodyA:body_a bodyB:body_b];
	else if(klass == cpBreakableJointGetClass())
	{
	}
	else if (klass == cpSimpleMotorGetClass())
		[self drawMotorJoint:(cpSimpleMotor*)_constraint bodyA:body_a bodyB:body_b];
	else if (klass == cpGearJointGetClass())
		[self drawGearJoint:(cpGearJoint*)_constraint bodyA:body_a bodyB:body_b];
	else if(klass == cpDampedSpringGetClass())
		[self drawSpringJoint:(cpDampedSpring *)_constraint bodyA:body_a bodyB:body_b];
	
	if( _opacity != 255 )
		glBlendFunc(CC_BLEND_SRC, CC_BLEND_DST);
}

- (void) drawPinJoint:(cpPinJoint*)joint bodyA:(cpBody*)body_a bodyB:(cpBody*)body_b
{	
	cpVect a = cpvadd(body_a->p, cpvrotate(joint->anchr1, body_a->rot));
	cpVect b = cpvadd(body_b->p, cpvrotate(joint->anchr2, body_b->rot));
	
	float *array = malloc( sizeof(float)*4);
	array[0] = a.x;
	array[1] = a.y;
	array[2] = b.x;
	array[3] = b.y;
	
	glVertexPointer(2, GL_FLOAT, 0, array);
	glEnableClientState(GL_VERTEX_ARRAY);
	
	glDrawArrays(GL_POINTS, 0, 2);
	glDrawArrays(GL_LINES, 0, 2);
	
	glDisableClientState(GL_VERTEX_ARRAY);	
	free(array);
}

- (void) drawSlideJoint:(cpSlideJoint*)joint bodyA:(cpBody*)body_a bodyB:(cpBody*)body_b
{	
	cpVect a = cpvadd(body_a->p, cpvrotate(joint->anchr1, body_a->rot));
	cpVect b = cpvadd(body_b->p, cpvrotate(joint->anchr2, body_b->rot));
	
	float *array = malloc( sizeof(float)*4);
	array[0] = a.x;
	array[1] = a.y;
	array[2] = b.x;
	array[3] = b.y;
	
	glVertexPointer(2, GL_FLOAT, 0, array);
	glEnableClientState(GL_VERTEX_ARRAY);
	
	glDrawArrays(GL_POINTS, 0, 2);
	glDrawArrays(GL_LINES, 0, 2);
	
	glDisableClientState(GL_VERTEX_ARRAY);	
	
	free(array);
}

- (void) drawPivotJoint:(cpPivotJoint*)joint bodyA:(cpBody*)body_a bodyB:(cpBody*)body_b
{	
	cpVect a = cpvadd(body_a->p, cpvrotate(joint->anchr1, body_a->rot));
	cpVect b = cpvadd(body_b->p, cpvrotate(joint->anchr2, body_b->rot));
	
	float *array = malloc( sizeof(float)*4);
	array[0] = a.x;
	array[1] = a.y;
	array[2] = b.x;
	array[3] = b.y;
	
	glVertexPointer(2, GL_FLOAT, 0, array);

	glEnableClientState(GL_VERTEX_ARRAY);
	glDrawArrays(GL_POINTS, 0, 2);	
	glDrawArrays(GL_LINES, 0, 2);
	glDisableClientState(GL_VERTEX_ARRAY);	
	
	free(array);
}

- (void) drawGrooveJoint:(cpGrooveJoint*)joint bodyA:(cpBody*)body_a bodyB:(cpBody*)body_b
{
	cpVect a = cpvadd(body_a->p, cpvrotate(joint->grv_a, body_a->rot));
	cpVect b = cpvadd(body_a->p, cpvrotate(joint->grv_b, body_a->rot));
		
	cpVect grv = cpvadd(body_a->p, cpvrotate(joint->r1, body_a->rot));
	
	float *groove = malloc(sizeof(float)*6);
	groove[0] = a.x;
	groove[1] = a.y;
	groove[2] = b.x;
	groove[3] = b.y;	
	groove[4] = grv.x;
	groove[5] = grv.y;

	glEnableClientState(GL_VERTEX_ARRAY);
		
	glVertexPointer(2, GL_FLOAT, 0, groove);
	glDrawArrays(GL_POINTS, 0, 3);
	glDrawArrays(GL_LINES, 0, 2);
		
	glDisableClientState(GL_VERTEX_ARRAY);	
	
	free(groove);
}

- (void) drawSpringJoint:(cpDampedSpring*)joint bodyA:(cpBody*)body_a bodyB:(cpBody*)body_b
{
	static const GLfloat springVAR[] = {
		0.00f, 0.0f,
		0.20f, 0.0f,
		0.25f, 3.0f,
		0.30f,-6.0f,
		0.35f, 6.0f,
		0.40f,-6.0f,
		0.45f, 6.0f,
		0.50f,-6.0f,
		0.55f, 6.0f,
		0.60f,-6.0f,
		0.65f, 6.0f,
		0.70f,-3.0f,
		0.75f, 6.0f,
		0.80f, 0.0f,
		1.00f, 0.0f,
	};
	static const int springVAR_count = sizeof(springVAR)/sizeof(GLfloat)/2;
	
	cpVect a = cpvadd(body_a->p, cpvrotate(joint->anchr1, body_a->rot));
	cpVect b = cpvadd(body_b->p, cpvrotate(joint->anchr2, body_b->rot));
	
	float *array = malloc( sizeof(float)*4);
	array[0] = a.x;
	array[1] = a.y;
	array[2] = b.x;
	array[3] = b.y;
	
	glVertexPointer(2, GL_FLOAT, 0, array);
	
	glEnableClientState(GL_VERTEX_ARRAY);
	glDrawArrays(GL_POINTS, 0, 2);	
	
	cpVect delta = cpvsub(b, a);
	
	glVertexPointer(2, GL_FLOAT, 0, springVAR);
	glPushMatrix(); {
		GLfloat x = a.x;
		GLfloat y = a.y;
		GLfloat cos = delta.x;
		GLfloat sin = delta.y;
		GLfloat s = 1.0f/cpvlength(delta);
		
		const GLfloat matrix[] = {
			cos,	sin,	0.0f, 0.0f,
			-sin*s, cos*s,	0.0f, 0.0f,
			0.0f,	0.0f,	1.0f, 1.0f,
			x,		y,		0.0f, 1.0f,
		};
		
		glMultMatrixf(matrix);
		glDrawArrays(GL_LINE_STRIP, 0, springVAR_count);
	} glPopMatrix();
	
	glDisableClientState(GL_VERTEX_ARRAY);	
	
	free(array);
}

- (void) drawBreakableJoint:(cpBreakableJoint*)joint bodyA:(cpBody*)body_a bodyB:(cpBody*)body_b
{
	
}

- (void) drawMotorJoint:(cpSimpleMotor*)joint bodyA:(cpBody*)body_a bodyB:(cpBody*)body_b
{
	drawCircle(body_a->p, 4.0, 0, 12, NO);
	//drawCircle(body_b->p, 4.0, 0, 12, NO);
}

- (void) drawGearJoint:(cpGearJoint*)joint bodyA:(cpBody*)body_a bodyB:(cpBody*)body_b
{
	cpFloat ratio = joint->ratio;
	
	cpFloat radius1 = fabs(5.0 / ratio);
	cpFloat radius2 = fabs(5.0 * ratio);
	
	drawCircle(body_a->p, radius1, 0, radius1*2+3, NO);
	drawCircle(body_b->p, radius2, 0, radius2*2+3, NO);
	
	cpVect a = cpv(0,radius1);
	cpVect b = cpv(0,radius2);
	cpVect c = cpv(0,-radius1);
	cpVect d = cpv(0,-radius2);
	
	float dx = body_a->p.x - body_b->p.x;
	float dy = body_a->p.y - body_b->p.y;
	cpVect rotation = cpvforangle(atan2f(dy,dx));	
	
	a = cpvadd(body_a->p, cpvrotate(a,rotation));
	b = cpvadd(body_b->p, cpvrotate(b,rotation));
	c = cpvadd(body_a->p, cpvrotate(c,rotation));
	d = cpvadd(body_b->p, cpvrotate(d,rotation));
	
	float *array = malloc(sizeof(float)*8);
	array[0] = a.x;
	array[1] = a.y;
	array[4] = c.x;
	array[5] = c.y;

	if (ratio >= 0)
	{
		array[2] = b.x;
		array[3] = b.y;
		array[6] = d.x;
		array[7] = d.y;
	}
	else 
	{
		array[2] = d.x;
		array[3] = d.y;
		array[6] = b.x;
		array[7] = b.y;
	}

	glVertexPointer(2, GL_FLOAT, 0, array);
	
	glEnableClientState(GL_VERTEX_ARRAY);
	//glDrawArrays(GL_POINTS, 0, 4);	
	glDrawArrays(GL_LINES, 0, 4);
	glDisableClientState(GL_VERTEX_ARRAY);	
}

@end
