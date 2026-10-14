#include "collision.hpp"
#include <chrono>
#include <condition_variable>
#include <cstring>
#include <fstream>
#include <functional>
#include <iostream>
#include <mutex>
#include <stdexcept>
#include <string>
using namespace cqcollision;
using Clock=std::chrono::steady_clock;
thread_local bool count_allocations=false;
thread_local uint64_t allocations=0;
void*operator new(std::size_t n){if(count_allocations)allocations++;if(void*p=std::malloc(n?n:1))return p;throw std::bad_alloc();}
void operator delete(void*p)noexcept{std::free(p);}void operator delete(void*p,std::size_t)noexcept{std::free(p);}
struct Reader{std::ifstream file;explicit Reader(const std::string&p):file(p,std::ios::binary){if(!file)throw std::runtime_error("cannot open input");}template<class T>T read(){T v{};if(!file.read(reinterpret_cast<char*>(&v),sizeof(v)))throw std::runtime_error("truncated input");return v;}V vector(){return{read<double>(),read<double>(),read<double>()};}void magic(const char*expected){char buf[8];if(!file.read(buf,8)||std::memcmp(buf,expected,8))throw std::runtime_error("bad magic");}};
Shape shape(Reader&r,bool query=false){Shape s;s.kind=Kind(r.read<uint32_t>());s.id=r.read<int32_t>();s.mask=r.read<uint32_t>();s.center=r.vector();s.half=r.vector();s.radius=r.read<double>();s.height=r.read<double>();s.basis={r.vector(),r.vector(),r.vector()};s.motion=r.vector();
 if(uint32_t(s.kind)>(query?5u:3u)||s.kind==Kind::triangle||!s.center.finite()||!s.half.finite()||!s.basis.x.finite()||!s.basis.y.finite()||!s.basis.z.finite()||!s.motion.finite()||!std::isfinite(s.radius)||!std::isfinite(s.height)||s.radius<0||s.height<0||s.half.x<0||s.half.y<0||s.half.z<0||
 std::abs(s.basis.x.length2()-1)>1e-5||std::abs(s.basis.y.length2()-1)>1e-5||std::abs(s.basis.z.length2()-1)>1e-5||
 std::abs(s.basis.x.dot(s.basis.y))>1e-5||std::abs(s.basis.x.dot(s.basis.z))>1e-5||std::abs(s.basis.y.dot(s.basis.z))>1e-5||
 (s.kind==Kind::capsule&&s.height<2*s.radius))throw std::runtime_error("invalid shape");
 return s;}
struct Query{Shape shape;V delta;bool expected;double fraction,unsafe_fraction;int id;V normal,position,velocity;int scenario;};
struct Result{Hit hit;Move move;Counters stats;uint64_t allocations=0;};
Result execute(const World&w,const Query&q){Result result;allocations=0;count_allocations=true;
 if(q.shape.kind==Kind::box)result.hit=w.ray(q.shape.center,q.delta,q.shape.mask,-1,result.stats);
 else if(uint32_t(q.shape.kind)==5)result.move=move_character(w,q.shape.center,q.delta,1./30,q.shape.radius,q.shape.height,-1,result.stats,false);
 else result.hit=w.sweep(q.shape,q.delta,.001,q.shape.mask,-1,result.stats);
 count_allocations=false;result.allocations=allocations;return result;
}
#ifdef CQ_JOLT_BACKEND
#include "jolt_backend.hpp"
#endif
class Pool{int n;std::vector<std::thread> threads;std::mutex mutex;std::condition_variable wake,done;std::function<void(int)> job;int generation=0,finished=0;bool stop=false;
 public:explicit Pool(int count):n(count){for(int id=1;id<n;id++)threads.emplace_back([this,id]{int seen=0;std::unique_lock<std::mutex> lock(mutex);while(true){wake.wait(lock,[&]{return stop||generation!=seen;});if(stop)return;seen=generation;auto task=job;lock.unlock();task(id);lock.lock();finished++;done.notify_one();}});}
 void run(const std::function<void(int)>&task){{std::lock_guard<std::mutex>lock(mutex);job=task;finished=0;generation++;}wake.notify_all();task(0);std::unique_lock<std::mutex>lock(mutex);done.wait(lock,[&]{return finished==n-1;});}
 ~Pool(){{std::lock_guard<std::mutex>lock(mutex);stop=true;}wake.notify_all();for(auto&t:threads)t.join();}
};
#ifndef CQ_NO_SUITE_MAIN
int main(int argc,char**argv){try{
 if(argc!=7){std::cerr<<"usage: suite WORLD TRACES CSV WORKERS REPEATS BATCH\n";return 2;}
 int workers=std::stoi(argv[4]),repeats=std::stoi(argv[5]),batch=std::stoi(argv[6]);if(workers<1||workers>8||repeats<1||repeats>1000||batch<1||batch>4096)throw std::runtime_error("bad benchmark limits");
 auto begin=Clock::now();Reader r(argv[1]);r.magic("CQCOLL1\0");World w;w.width=int(r.read<uint32_t>());w.depth=int(r.read<uint32_t>());w.spacing=r.read<double>();w.origin=r.vector();w.diagonal_ad=r.read<uint32_t>()!=0;uint32_t count=r.read<uint32_t>();
 if(w.width<2||w.depth<2||uint64_t(w.width)*w.depth>16777216||count>1000000||!std::isfinite(w.spacing)||w.spacing<=0||!w.origin.finite())throw std::runtime_error("bad world limits");
 w.heights.resize(size_t(w.width)*w.depth);for(float &h:w.heights){h=r.read<float>();if(!std::isfinite(h))throw std::runtime_error("nonfinite terrain");}for(uint32_t i=0;i<count;i++)w.objects.push_back(shape(r));
#ifndef CQ_JOLT_BACKEND
 w.build();
#endif
 Reader tr(argv[2]);tr.magic("CQTRACE2");uint32_t qcount=tr.read<uint32_t>();if(qcount>1000000)throw std::runtime_error("too many traces");std::vector<Query> queries;for(uint32_t i=0;i<qcount;i++){Query q;q.shape=shape(tr,true);q.delta=tr.vector();q.expected=tr.read<uint32_t>()!=0;q.fraction=tr.read<double>();q.unsafe_fraction=tr.read<double>();q.id=tr.read<int32_t>();q.normal=tr.vector();q.position=tr.vector();q.velocity=tr.vector();q.scenario=int(tr.read<uint32_t>());if(!q.delta.finite()||!q.position.finite()||!q.normal.finite()||!q.velocity.finite()||!std::isfinite(q.fraction)||!std::isfinite(q.unsafe_fraction)||q.fraction<0||q.fraction>1||q.unsafe_fraction<0||q.unsafe_fraction>1)throw std::runtime_error("bad trace");queries.push_back(q);}
#ifdef CQ_JOLT_BACKEND
 JoltBackend backend(w,queries);
 auto execute_query=[&](int index,int worker){return backend.execute(queries[index],size_t(index),worker);};
#else
 auto execute_query=[&](int index,int){return execute(w,queries[index]);};
#endif
 double setup=std::chrono::duration<double,std::milli>(Clock::now()-begin).count();std::vector<Result> results(qcount);std::vector<double> batches;Pool pool(workers);std::vector<std::vector<double>> type_batches(6);
 // Homogeneous command batches make 32/64-query timings interpretable.
 for(int kind:{0,1,2,3,5}){std::vector<int> indices;for(uint32_t i=0;i<qcount;i++)if(int(queries[i].shape.kind)==kind)indices.push_back(int(i));if(indices.empty())continue;
  for(int warm=0;warm<2;warm++)for(int i:indices)results[i]=execute_query(i,0);
  for(int rep=0;rep<repeats;rep++)for(size_t start=0;start<indices.size();start+=batch){size_t size=std::min(size_t(batch),indices.size()-start);auto tick=Clock::now();pool.run([&](int worker){size_t a=start+size*worker/workers,b=start+size*(worker+1)/workers;for(size_t i=a;i<b;i++){int index=indices[i];results[index]=execute_query(index,worker);}});double ms=std::chrono::duration<double,std::milli>(Clock::now()-tick).count();if(size==size_t(batch)){batches.push_back(ms);type_batches[kind].push_back(ms);}}
 }
 std::ofstream csv(argv[3]);csv<<"index,kind,scenario,hit,fraction,id,nx,ny,nz,converged,px,py,pz,vx,vy,vz,grounded,candidates,triangles,gjk,iterations,advances,recoveries,unresolved,allocations\n";Counters totals;uint64_t allocs=0;
 for(uint32_t i=0;i<qcount;i++){auto &v=results[i];auto &q=queries[i];totals.add(v.stats);allocs+=v.allocations;csv.precision(12);csv<<i<<','<<int(q.shape.kind)<<','<<q.scenario<<','<<v.hit.hit<<','<<v.hit.fraction<<','<<v.hit.id<<','<<v.hit.normal.x<<','<<v.hit.normal.y<<','<<v.hit.normal.z<<','<<(int(q.shape.kind)==5?v.move.converged:v.hit.converged)<<','<<v.move.position.x<<','<<v.move.position.y<<','<<v.move.position.z<<','<<v.move.velocity.x<<','<<v.move.velocity.y<<','<<v.move.velocity.z<<','<<v.move.grounded<<','<<v.stats.candidates<<','<<v.stats.triangles<<','<<v.stats.gjk<<','<<v.stats.iterations<<','<<v.stats.advances<<','<<v.stats.recoveries<<','<<v.stats.unresolved<<','<<v.allocations<<'\n';}
 auto distribution=[](std::vector<double> values){if(values.empty())return std::string("{}");std::sort(values.begin(),values.end());return std::string("{\"samples\":")+std::to_string(values.size())+",\"p50\":"+std::to_string(values[values.size()/2])+",\"p95\":"+std::to_string(values[size_t(values.size()*.95)])+",\"p99\":"+std::to_string(values[size_t(values.size()*.99)])+",\"max\":"+std::to_string(values.back())+"}";};
 std::cout<<"{\"workers\":"<<workers<<",\"batch\":"<<batch<<",\"queries\":"<<qcount<<",\"primitives\":"<<count<<",\"setup_ms\":"<<setup<<",\"query_allocations\":"<<allocs<<",\"unresolved\":"<<totals.unresolved<<",\"candidate_tests\":"<<totals.candidates<<",\"triangle_tests\":"<<totals.triangles<<",\"gjk_calls\":"<<totals.gjk<<",\"gjk_iterations\":"<<totals.iterations<<",\"batch_ms\":"<<distribution(batches)<<",\"by_kind\":{";
 bool comma=false;for(int i:{0,1,2,3,5}){if(comma)std::cout<<',';comma=true;std::cout<<'"'<<i<<"\":"<<distribution(type_batches[i]);}std::cout<<"},\"backend\":\""
#ifdef CQ_JOLT_BACKEND
 <<"jolt-5.6.0"
#else
 <<"custom"
#endif
 <<"\"}\n";
 return 0;
 }catch(const std::exception&e){std::cerr<<e.what()<<'\n';return 2;}}

#endif // CQ_NO_SUITE_MAIN
