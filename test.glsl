vec3[] spherePositions = vec3[](vec3(0, 8, 20), vec3(0, 3, 20), vec3(0, -4, -10), vec3(0, -9, 20), vec3(7, 0, 40), vec3(12, 4, 15));
float[] sphereRadii = float[](2., 3., 4., 5., 20., 3.);
vec3[] sphereColors = vec3[](vec3(1,0,0),vec3(0,0,1),vec3(0,1,0),vec3(1,0,1),vec3(1,1,1),vec3(1,1,0));
float[] reflectionAmount = float[](0., 0., 0., 0.2, 0.8, 0.3); //0 = flat, 1 = mirror

float planeHeight = -8.;
float planeReflectivity = .3;
vec3 sun;

bool shadowCast(vec3 point, vec3 sun){
    vec3 rayDir = sun - point;
    rayDir = normalize(rayDir);

    for(int i = 0; i < spherePositions.length(); i++){
        float b = 2.0 * dot(rayDir, point - spherePositions[i]);
        float a = dot(rayDir, rayDir);
        float c = dot(point, point) + dot(spherePositions[i], spherePositions[i]) - 2. * dot(point, spherePositions[i]) - sphereRadii[i] * sphereRadii[i];
        
        float rt = b*b - 4. * a * c;
        float distance = (-b - sqrt(rt)) / 2. * a;
        if(distance > 0.){
            return true;
        }
    }
    return false;
}

vec3 castRay(vec3 origin, vec3 rayDir, int ignoreIndex, out vec3 reflectionPoint, out vec3 reflectionDirection, out float refAmount, out int reflectIndex){
    vec3 fragColor = vec3(.5, .6, .8);
    
    float minDist = 1000.;
    
    //Plane Drawing
    if(ignoreIndex != -1 && (planeHeight - origin.y) / rayDir.y < minDist && rayDir.y / (planeHeight - origin.y) > 0.){
        minDist = (planeHeight - origin.y) / rayDir.y;

        float grid = mod(floor((rayDir * ((planeHeight - origin.y) / rayDir.y) ).x + origin.x) + floor((rayDir * ((planeHeight - origin.y) / rayDir.y) ).z + origin.z), 2.);
        fragColor = vec3(grid, grid, grid);

        vec3 normal = vec3(0, 1, 0);
        refAmount = planeReflectivity;

        if(planeReflectivity > 0.){   //R = V - 2 * (N dot V) * N
            vec3 newRayDir = rayDir - 2. * dot(normal, rayDir) * normal;
            reflectionPoint = rayDir * ((planeHeight - origin.y) / rayDir.y) + origin;
            reflectionDirection = newRayDir;
            reflectIndex = -1;
        }
        
        if(shadowCast(rayDir * (planeHeight - origin.y) / rayDir.y + origin, sun)){
            fragColor *= .2;
        }
    }
    
    //Loop through spheres
    for(int i = 0; i < spherePositions.length(); i++){
        if(i == ignoreIndex)
            continue;
        float b = 2.0 * dot(rayDir, origin - spherePositions[i]);
        float a = 1.;
        float c = dot(origin, origin) + dot(spherePositions[i], spherePositions[i]) - 2. * dot(origin, spherePositions[i]) - sphereRadii[i] * sphereRadii[i];
        
        float rt = b*b - 4. * a * c;
        if(rt > 0.){
            float distance = (-b - sqrt(rt)) / 2. * a; //transparency by taking the positive root(starting a ray on the other side of the sphere)
            if(distance <= 0.)
                continue;
            vec3 point = origin + rayDir * distance;
            vec3 normal = normalize(point - spherePositions[i]);
            
            float luminosity = dot(normalize(sun - point), normal);
            if(luminosity < 0.){
                luminosity = 0.;
            }
            if(distance < minDist){
                minDist = distance;
                fragColor = vec3(luminosity * sphereColors[i]); //eventually save depth texture to seperate image so I can do shadows after calculating depth
                
                refAmount = reflectionAmount[i];
                if(reflectionAmount[i] > 0.){   //R = V - 2 * (N dot V) * N
                    vec3 newRayDir = rayDir - 2. * dot(normal, rayDir) * normal;
                    reflectionPoint = point;
                    reflectionDirection = newRayDir;
                    reflectIndex = i;
                }

                if(shadowCast(point, sun)){
                    fragColor *= .2;
                }
            }
        }
    }

    return vec3(fragColor);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    sun = vec3(10, 20, 5);
    float aspectRatio = iResolution.x/iResolution.y;
    vec2 uv = fragCoord.xy/iResolution.xy * 2. - 1.;
    uv.x *= aspectRatio;
    vec3 origin = vec3(10. * sin(iTime),0,0);

    float fov = 70.0; // Field of view in degrees
    float focalLength = 1.0 / tan(radians(fov) / 2.0);
    vec3 rayDir = normalize(vec3(uv * focalLength, 1.0));


    //vec3 rayDir = vec3((iResolution.x/2.-uv.x)/iResolution.y, (iResolution.y/2.-uv.y)/iResolution.y, .5);
    rayDir = normalize(rayDir);
    
    //fragColor = vec4(castRay(vec3(10. * sin(iTime),0,0), rayDir, 3));
    vec3 color = vec3(0, 0, 0);
    int reflectionCount = 0;
    float reflectionPercent = 1.;

    vec3 startPoint = origin;
    vec3 rayDirection = rayDir;
    int ignoreIndex = -2;

    while(reflectionCount < 7 && reflectionPercent > 0.){
        float refAmount;
        vec3 currentColor = castRay(startPoint, rayDirection, ignoreIndex, startPoint, rayDirection, refAmount, ignoreIndex);
        color += currentColor * reflectionPercent * (1. - refAmount);
        reflectionPercent *= refAmount;
        reflectionCount++;
    }
    fragColor = vec4(color, 1);
    
    //fragColor = vec4(minDist / 40., minDist/40., minDist / 40., 1);
}

