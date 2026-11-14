# Same instances and upper bounds as chao.batch, one Julia process per instance (run from the TOP folder);
# the instances commented out in the batch are commented out here.
mkdir -p out
julia src/run.jl data/p4.2.a.txt --cfg config/TOP.cfg -u -205 &> out/p4.2.a.out
julia src/run.jl data/p4.2.b.txt --cfg config/TOP.cfg -u -340 &> out/p4.2.b.out
julia src/run.jl data/p4.2.c.txt --cfg config/TOP.cfg -u -451 &> out/p4.2.c.out
julia src/run.jl data/p4.2.d.txt --cfg config/TOP.cfg -u -530 &> out/p4.2.d.out
julia src/run.jl data/p4.2.e.txt --cfg config/TOP.cfg -u -617 &> out/p4.2.e.out
julia src/run.jl data/p4.2.f.txt --cfg config/TOP.cfg -u -686 &> out/p4.2.f.out
julia src/run.jl data/p4.2.g.txt --cfg config/TOP.cfg -u -756 &> out/p4.2.g.out
julia src/run.jl data/p4.2.h.txt --cfg config/TOP.cfg -u -834 &> out/p4.2.h.out
julia src/run.jl data/p4.2.i.txt --cfg config/TOP.cfg -u -917 &> out/p4.2.i.out
julia src/run.jl data/p4.2.j.txt --cfg config/TOP.cfg -u -964 &> out/p4.2.j.out
julia src/run.jl data/p4.2.k.txt --cfg config/TOP.cfg -u -1021 &> out/p4.2.k.out
julia src/run.jl data/p4.2.l.txt --cfg config/TOP.cfg -u -1073 &> out/p4.2.l.out
julia src/run.jl data/p4.2.m.txt --cfg config/TOP.cfg -u -1131 &> out/p4.2.m.out
# julia src/run.jl data/p4.2.n.txt --cfg config/TOP.cfg &> out/p4.2.n.out   (not solved in 2 minutes: lower bound -1179.00, best -1168)
# julia src/run.jl data/p4.2.o.txt --cfg config/TOP.cfg &> out/p4.2.o.out   (not solved in 2 minutes: lower bound -1219.00, best -1216)
# julia src/run.jl data/p4.2.p.txt --cfg config/TOP.cfg &> out/p4.2.p.out   (not solved in 2 minutes: lower bound -1252.00, best 0)
# julia src/run.jl data/p4.2.q.txt --cfg config/TOP.cfg &> out/p4.2.q.out   (not solved in 2 minutes: lower bound -1278.00, best 0)
# julia src/run.jl data/p4.2.r.txt --cfg config/TOP.cfg &> out/p4.2.r.out   (not solved in 2 minutes: lower bound -1296.00, best 0)
# julia src/run.jl data/p4.2.s.txt --cfg config/TOP.cfg &> out/p4.2.s.out   (not solved in 2 minutes: lower bound -1305.00, best 0)
# julia src/run.jl data/p4.2.t.txt --cfg config/TOP.cfg &> out/p4.2.t.out   (not solved in 2 minutes: lower bound -1306.00, best -618)
julia src/run.jl data/p4.3.a.txt --cfg config/TOP.cfg -u 1 &> out/p4.3.a.out
julia src/run.jl data/p4.3.b.txt --cfg config/TOP.cfg -u -37 &> out/p4.3.b.out
julia src/run.jl data/p4.3.c.txt --cfg config/TOP.cfg -u -192 &> out/p4.3.c.out
julia src/run.jl data/p4.3.d.txt --cfg config/TOP.cfg -u -334 &> out/p4.3.d.out
julia src/run.jl data/p4.3.e.txt --cfg config/TOP.cfg -u -467 &> out/p4.3.e.out
julia src/run.jl data/p4.3.f.txt --cfg config/TOP.cfg -u -578 &> out/p4.3.f.out
julia src/run.jl data/p4.3.g.txt --cfg config/TOP.cfg -u -652 &> out/p4.3.g.out
julia src/run.jl data/p4.3.h.txt --cfg config/TOP.cfg -u -728 &> out/p4.3.h.out
julia src/run.jl data/p4.3.i.txt --cfg config/TOP.cfg -u -808 &> out/p4.3.i.out
julia src/run.jl data/p4.3.j.txt --cfg config/TOP.cfg -u -860 &> out/p4.3.j.out
julia src/run.jl data/p4.3.k.txt --cfg config/TOP.cfg -u -918 &> out/p4.3.k.out
julia src/run.jl data/p4.3.l.txt --cfg config/TOP.cfg -u -978 &> out/p4.3.l.out
julia src/run.jl data/p4.3.m.txt --cfg config/TOP.cfg -u -1062 &> out/p4.3.m.out
julia src/run.jl data/p4.3.n.txt --cfg config/TOP.cfg -u -1120 &> out/p4.3.n.out
julia src/run.jl data/p4.3.o.txt --cfg config/TOP.cfg -u -1171 &> out/p4.3.o.out
julia src/run.jl data/p4.3.p.txt --cfg config/TOP.cfg -u -1221 &> out/p4.3.p.out
julia src/run.jl data/p4.3.q.txt --cfg config/TOP.cfg -u -1252 &> out/p4.3.q.out
# julia src/run.jl data/p4.3.r.txt --cfg config/TOP.cfg &> out/p4.3.r.out   (not solved in 2 minutes: lower bound -1279.00, best -1266)
# julia src/run.jl data/p4.3.s.txt --cfg config/TOP.cfg &> out/p4.3.s.out   (not solved in 2 minutes: lower bound -1297.00, best -1274)
# julia src/run.jl data/p4.3.t.txt --cfg config/TOP.cfg &> out/p4.3.t.out   (not solved in 2 minutes: lower bound -1306.00, best -584)
julia src/run.jl data/p4.4.a.txt --cfg config/TOP.cfg -u 1 &> out/p4.4.a.out
julia src/run.jl data/p4.4.b.txt --cfg config/TOP.cfg -u 1 &> out/p4.4.b.out
julia src/run.jl data/p4.4.c.txt --cfg config/TOP.cfg -u 1 &> out/p4.4.c.out
julia src/run.jl data/p4.4.d.txt --cfg config/TOP.cfg -u -37 &> out/p4.4.d.out
julia src/run.jl data/p4.4.e.txt --cfg config/TOP.cfg -u -182 &> out/p4.4.e.out
julia src/run.jl data/p4.4.f.txt --cfg config/TOP.cfg -u -323 &> out/p4.4.f.out
julia src/run.jl data/p4.4.g.txt --cfg config/TOP.cfg -u -460 &> out/p4.4.g.out
julia src/run.jl data/p4.4.h.txt --cfg config/TOP.cfg -u -570 &> out/p4.4.h.out
julia src/run.jl data/p4.4.i.txt --cfg config/TOP.cfg -u -656 &> out/p4.4.i.out
julia src/run.jl data/p4.4.j.txt --cfg config/TOP.cfg -u -731 &> out/p4.4.j.out
julia src/run.jl data/p4.4.k.txt --cfg config/TOP.cfg -u -820 &> out/p4.4.k.out
julia src/run.jl data/p4.4.l.txt --cfg config/TOP.cfg -u -879 &> out/p4.4.l.out
# julia src/run.jl data/p4.4.m.txt --cfg config/TOP.cfg &> out/p4.4.m.out   (not solved in 2 minutes: lower bound -923.00, best -905)
# julia src/run.jl data/p4.4.n.txt --cfg config/TOP.cfg &> out/p4.4.n.out   (not solved in 2 minutes: lower bound -979.00, best -969)
julia src/run.jl data/p4.4.o.txt --cfg config/TOP.cfg -u -1060 &> out/p4.4.o.out
julia src/run.jl data/p4.4.p.txt --cfg config/TOP.cfg -u -1123 &> out/p4.4.p.out
julia src/run.jl data/p4.4.q.txt --cfg config/TOP.cfg -u -1160 &> out/p4.4.q.out
julia src/run.jl data/p4.4.r.txt --cfg config/TOP.cfg -u -1215 &> out/p4.4.r.out
# julia src/run.jl data/p4.4.s.txt --cfg config/TOP.cfg &> out/p4.4.s.out   (not solved in 2 minutes: lower bound -1264.00, best -1254)
# julia src/run.jl data/p4.4.t.txt --cfg config/TOP.cfg &> out/p4.4.t.out   (not solved in 2 minutes: lower bound -1291.00, best -1277)
