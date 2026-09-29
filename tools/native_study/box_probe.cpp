// Experimental standalone port of hit_detection.gd::box_fraction, not game code.
// Float vectors / double scalar arithmetic follow the standard Godot build.
#include <algorithm>
#include <array>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <limits>
#include <vector>
using V = std::array<float,3>;
struct Case { V start,end,half; double radius,expected; };
constexpr double inf=std::numeric_limits<double>::infinity();
static V lerp(const V &a,const V &b,double t) {
    V result{}; for(int i=0;i<3;++i) result[i]=a[i]+float(t)*(b[i]-a[i]); return result;
}
static double dot(const V &a,const V &b) {return a[0]*b[0]+a[1]*b[1]+a[2]*b[2];}
static double box(const Case &p) {
    V motion{};for(int i=0;i<3;++i) motion[i]=p.end[i]-p.start[i];
    double enter=0,leave=1;
    for(int axis=0;axis<3;++axis) {
        const double extent=p.half[axis]+p.radius+.000001;
        if(std::abs(motion[axis])<1e-10) {if(std::abs(p.start[axis])>extent)return inf;}
        else {
            const double a=(-extent-p.start[axis])/motion[axis],b=(extent-p.start[axis])/motion[axis];
            enter=std::max(enter,std::min(a,b));leave=std::min(leave,std::max(a,b));
            if(enter>leave)return inf;
        }
    }
    if(p.radius<=0)return enter;
    std::array<double,8> cuts{};int count=2;cuts[0]=enter;cuts[1]=leave;
    for(int axis=0;axis<3;++axis) {
        if(std::abs(motion[axis])<1e-10)continue;
        for(double sign:{-1.,1.}) {
            const double t=(sign*p.half[axis]-p.start[axis])/motion[axis];
            if(t>enter && t<leave)cuts[count++]=t;
        }
    }
    for(int i=1;i<count;++i) { const double value=cuts[i]; int j=i;
        while(j>0 && cuts[j-1]>value) {cuts[j]=cuts[j-1];--j;} cuts[j]=value; }
    V point=lerp(p.start,p.end,enter),distance{};
    for(int i=0;i<3;++i)distance[i]=point[i]-std::clamp(point[i],-p.half[i],p.half[i]);
    if(dot(distance,distance)<=p.radius*p.radius+1e-10)return enter;
    for(int i=0;i<count-1;++i) {
        const double low=cuts[i],high=cuts[i+1];const V mid=lerp(p.start,p.end,(low+high)*.5);
        V offset{},velocity{};
        for(int axis=0;axis<3;++axis) if(std::abs(mid[axis])>p.half[axis]) {
            offset[axis]=p.start[axis]-(mid[axis]>0 ? 1.f:-1.f)*p.half[axis];velocity[axis]=motion[axis];
        }
        const double a=dot(velocity,velocity),b=dot(offset,velocity),c=dot(offset,offset)-p.radius*p.radius;
        if(a<1e-12)continue;
        const double discriminant=b*b-a*c;
        if(discriminant<0)continue;
        const double contact=(-b-std::sqrt(discriminant))/a;
        if(contact>=low-1e-7 && contact<=high+1e-7)return std::clamp(contact,low,high);
    }
    return inf;
}
int main(int argc,char **argv) {
    if(argc!=2)return 2;
    std::ifstream file(argv[1],std::ios::binary);uint32_t count=0;
    file.read(reinterpret_cast<char*>(&count),4);if(!file || count>1000000)return 2;
    std::vector<Case> cases(count);
    for(auto &p:cases) {
        for(auto *v:{&p.start,&p.end,&p.half})file.read(reinterpret_cast<char*>(v->data()),12);
        file.read(reinterpret_cast<char*>(&p.radius),8);file.read(reinterpret_cast<char*>(&p.expected),8);
    }
    if(!file)return 2;
    int mismatch=0;double max_error=0;
    for(const auto &p:cases) {
        const double got=box(p);
        if(std::isfinite(got)!=std::isfinite(p.expected))++mismatch;
        else if(std::isfinite(got)) {const double error=std::abs(got-p.expected);max_error=std::max(max_error,error);if(error>1e-5)++mismatch;}
    }
    std::vector<double> times;double checksum=0;int contacts=0;
    for(int trial=0;trial<6;++trial) {
        auto before=std::chrono::steady_clock::now();checksum=0;contacts=0;
        for(const auto &p:cases) {const double value=box(p);if(std::isfinite(value)){checksum+=value;++contacts;}}
        const double ms=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-before).count();
        if(trial>0)times.push_back(ms);
        // Observable each pass: prevents the compiler eliminating repeated work.
        std::cerr<<"pass "<<trial<<" checksum "<<std::setprecision(17)<<checksum<<'\n';
    }
    std::cout<<std::setprecision(12)<<"{\"cases\":"<<count<<",\"mismatches\":"<<mismatch<<",\"max_error\":"<<max_error<<",\"contacts\":"<<contacts<<",\"checksum\":"<<checksum<<",\"milliseconds\":[";
    for(size_t i=0;i<times.size();++i)std::cout<<(i?",":"")<<times[i];
    std::cout<<"]}\n";return mismatch?1:0;
}
