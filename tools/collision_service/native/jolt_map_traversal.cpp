#define CQ_JOLT_BACKEND
#define CQ_NO_SUITE_MAIN
#include "suite.cpp"
int main(int argc,char**argv){try{
 if(argc!=3)throw std::runtime_error("usage: collision_jolt_map_traversal WORLD FLIGHTS");
 Reader r(argv[1]);r.magic("CQCOLL1\0");World world;world.width=int(r.read<uint32_t>());world.depth=int(r.read<uint32_t>());world.spacing=r.read<double>();world.origin=r.vector();world.diagonal_ad=r.read<uint32_t>()!=0;auto count=r.read<uint32_t>();
 if(world.width<2||world.depth<2||uint64_t(world.width)*world.depth>16777216||count>1000000)throw std::runtime_error("bad traversal world limits");
 world.heights.resize(size_t(world.width)*world.depth);for(float&h:world.heights)h=r.read<float>();for(uint32_t i=0;i<count;i++)world.objects.push_back(shape(r));
 Reader flights(argv[2]);flights.magic("CQFLIGHT");uint32_t n=flights.read<uint32_t>();if(n>1024)throw std::runtime_error("excessive flights");std::vector<V> starts,ends;std::vector<Query> queries;
 for(uint32_t i=0;i<n;i++){
  V start=flights.vector(),end=flights.vector();starts.push_back(start);ends.push_back(end);double slope=(end.y-start.y)/(end.z-start.z);
  Query q{};q.shape.kind=Kind(5);q.shape.radius=.3;q.shape.height=1.65;q.shape.center=start+V{0,.45*slope+.3*slope-.005,.45};q.delta={0,-.2,3};queries.push_back(q);
 }
 JoltBackend jolt(world,queries);int failed=0;std::cout<<"{\"flights\":"<<n<<",\"results\":[";
 for(uint32_t i=0;i<n;i++){
  Query q=queries[i];bool valid=true;int overflow=0;
  for(int tick=0;tick<95;tick++){auto result=jolt.execute(q,i,0);q.shape.center=result.move.position;q.delta.y=result.move.grounded?-.2:std::max(-30.,result.move.velocity.y-25./30);valid&=result.move.converged;if(!result.move.converged)overflow++;}
  V upper=q.shape.center;bool up=upper.z>=ends[i].z-.25&&std::abs(upper.y-ends[i].y)<.04;
  q.delta.z=-3;
  for(int tick=0;tick<95;tick++){auto result=jolt.execute(q,i,0);q.shape.center=result.move.position;q.delta.y=result.move.grounded?-.2:std::max(-30.,result.move.velocity.y-25./30);valid&=result.move.converged;if(!result.move.converged)overflow++;}
  bool down=q.shape.center.z<starts[i].z+.8&&q.shape.center.y<starts[i].y+.5;bool pass=valid&&up&&down;if(!pass)failed++;
  if(i)std::cout<<',';
  std::cout<<"{\"index\":"<<i<<",\"up\":"<<(up?"true":"false")<<",\"down\":"<<(down?"true":"false")<<",\"overflow\":"<<overflow<<",\"upper_y_error_m\":"<<upper.y-ends[i].y<<",\"upper_z_from_landing_m\":"<<upper.z-ends[i].z<<",\"lower_y_from_start_m\":"<<q.shape.center.y-starts[i].y<<"}";
 }
 std::cout<<"],\"failed\":"<<failed<<",\"ticks_per_direction\":95,\"stair_assist\":false}\n";return failed?1:0;
 }catch(const std::exception&e){std::cerr<<e.what()<<'\n';return 2;}}
