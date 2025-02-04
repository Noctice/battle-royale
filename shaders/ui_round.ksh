   ui_round   	   MatrixPVW                                                                                IMAGE_PARAMS                                IMAGE_PARAMS2                                SCREEN_PARAMS                                zdy.vs6  uniform mat4 MatrixPVW;
//attribute 限定符: 从“外部”到顶点着色器的通信
attribute vec3 POSITION;
attribute vec2 TEXCOORD0;
attribute vec4 DIFFUSE;

//varying 限定符: varying限定的变量只能在shader之间传递顶点着色器的输出，片段着色器的输入，Shader中的声明和类型要保持一致。
varying vec2 PS_TEXCOORD;
varying vec4 PS_COLOUR;

void main()
{
	gl_Position = MatrixPVW * vec4( POSITION.xyz, 1.0 );
	PS_TEXCOORD.xy = TEXCOORD0.xy;
	PS_COLOUR.rgba = vec4( DIFFUSE.rgb * DIFFUSE.a, DIFFUSE.a );
}    zdy.ps�	  // 设置浮点类型
#if defined( GL_ES )
precision mediump float;
#endif

//varying 限定符: varying限定的变量只能在shader之间传递顶点着色器的输出，片段着色器的输入，Shader中的声明和类型要保持一致。
uniform sampler2D SAMPLER[1]; //传入的图片数据吧
varying vec2 PS_TEXCOORD; //纹理坐标系？
varying vec4 PS_COLOUR; //颜色？

// uniform 限定符: 应用程序传递过来的变量
// 对应着 SetAlphaRange 传入的两个数据
uniform vec2 ALPHA_RANGE;
// 对应着 SetEffectParams 传入的四个数据
uniform vec4 IMAGE_PARAMS;
// 对应着 SetEffectParams2 传入的四个数据
uniform vec4 IMAGE_PARAMS2;

// 屏幕参数
uniform vec4 SCREEN_PARAMS;

// #define:定义宏 相当于给 IMAGE_PARAMS.y 添加别名？或者说是记录指针
// 大圆 圆心
#define BIG_X       IMAGE_PARAMS.x
#define BIG_Y       IMAGE_PARAMS.y
// 大圆 半径
#define BIG_R       IMAGE_PARAMS.z

// 小圆 圆心
#define SMALL_X     IMAGE_PARAMS2.x
#define SMALL_Y     IMAGE_PARAMS2.y
// 小圆 半径
#define SMALL_R     IMAGE_PARAMS2.z
#define SMALL_B     IMAGE_PARAMS2.w


#define W_H  (SCREEN_PARAMS.x / SCREEN_PARAMS.y)

 
void main()
{

    vec4 colour = texture2D(SAMPLER[0], PS_TEXCOORD.xy );
    colour.rgba = PS_COLOUR.rgba;
    vec4 fixedcolour = vec4(colour.rgba);

    // 圆内
    vec4 colorCircle = vec4(0.000,0.000,0.000,0.00);
    //背景色
    vec4 colorBg = vec4(0.250,0.100,0.050,0.300);
    // 大圈颜色
    vec4 colourBgEdge = vec4(0.6,0.4,0.1,0.5);
    // 小圈颜色
    vec4 colourEdge = vec4(1.0,1.0,1.0,1.0);


    // 计算屏幕空间中的当前片段位置
    vec2 screenPos = PS_TEXCOORD * SCREEN_PARAMS.xy;

    // 计算当前片段到圆心的距离
    float d1 = length(screenPos - vec2(BIG_X, BIG_Y));

    float d2 = length(screenPos - vec2(SMALL_X, SMALL_Y));


    if (d2 < SMALL_R && d2 > SMALL_R - SMALL_B)
    {
        fixedcolour.rgba *= colourEdge.rgba;
    }
    else
    {
        if (d1 < BIG_R && d1 > BIG_R - SMALL_B)
        {
            fixedcolour.rgba *= colourBgEdge.rgba;
        }
        else
        {
            if (d1 < BIG_R)
            {
                fixedcolour.rgba *= colorCircle.rgba;
            }
            else
            {
                fixedcolour.rgba *= colorBg.rgba;
            }
        }
    }

    gl_FragColor = fixedcolour; 
}                    