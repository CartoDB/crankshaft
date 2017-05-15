--
-- Test data for spatial interactions models
--

SET client_min_messages TO WARNING;
\set ECHO none

CREATE TABLE austria_test (
    cartodb_id integer,
    origin text,
    destination text,
    origin_i integer,
    destination_j integer,
    flow_data integer,
    dij double precision
);

COPY austria_test (cartodb_id, origin, destination, origin_i, destination_j, flow_data, dij) FROM stdin;
9	AT11	AT34	4016	1910	19	505.089539000000002
8	AT11	AT33	4016	3952	43	390.856110000000001
7	AT11	AT32	4016	4902	31	246.93330499999999
6	AT11	AT31	4016	8193	98	214.511813999999987
5	AT11	AT22	4016	8634	738	132.007479999999987
4	AT11	AT21	4016	4117	69	220.81193300000001
3	AT11	AT13	4016	26980	1887	84.2046660000000031
2	AT11	AT12	4016	25741	1131	103.001845000000003
1	AT11	AT11	4016	5146	0	1.00000000000000003e-300
45	AT22	AT34	8487	1910	262	376.346670000000017
44	AT22	AT33	8487	3952	425	261.893782999999985
43	AT22	AT32	8487	4902	622	122.433524000000006
42	AT22	AT31	8487	8193	1081	124.563096000000002
41	AT22	AT22	8487	8634	0	1.00000000000000003e-300
40	AT22	AT21	8487	4117	1252	92.4079579999999936
39	AT22	AT13	8487	26980	2973	158.630661000000003
38	AT22	AT12	8487	25741	1110	129.878172000000006
37	AT22	AT11	8487	5146	762	132.007479999999987
18	AT12	AT34	20080	1910	159	453.515594000000021
17	AT12	AT33	20080	3952	303	343.500749999999982
16	AT12	AT32	20080	4902	388	201.232355000000013
15	AT12	AT31	20080	8193	1850	140.706671
14	AT12	AT22	20080	8634	1276	129.878172000000006
13	AT12	AT21	20080	4117	416	216.99473900000001
12	AT12	AT13	20080	26980	14055	45.7962720000000019
11	AT12	AT12	20080	25741	0	1.00000000000000003e-300
10	AT12	AT11	20080	5146	1633	103.001845000000003
54	AT31	AT34	10638	1910	274	314.793199000000016
53	AT31	AT33	10638	3952	821	208.456382999999988
52	AT31	AT32	10638	4902	2144	81.7536520000000024
51	AT31	AT31	10638	8193	0	1.00000000000000003e-300
50	AT31	AT22	10638	8634	1332	124.563096000000002
49	AT31	AT21	10638	4117	346	151.777156999999988
48	AT31	AT13	10638	26980	3498	186.420738
47	AT31	AT12	10638	25741	2027	140.706671
46	AT31	AT11	10638	5146	196	214.511813999999987
72	AT33	AT34	4341	1910	569	114.463250000000002
71	AT33	AT33	4341	3952	0	1.00000000000000003e-300
70	AT33	AT32	4341	4902	546	145.076471999999995
69	AT33	AT31	4341	8193	577	208.456382999999988
68	AT33	AT22	4341	8634	670	261.893782999999985
67	AT33	AT21	4341	4117	490	194.851668999999987
66	AT33	AT13	4341	26980	978	387.617759999999976
65	AT33	AT12	4341	25741	424	343.500749999999982
64	AT33	AT11	4341	5146	87	390.856110000000001
63	AT32	AT34	5790	1910	106	258.591197000000022
62	AT32	AT33	5790	3952	630	145.076471999999995
61	AT32	AT32	5790	4902	0	1.00000000000000003e-300
60	AT32	AT31	5790	8193	2117	81.7536520000000024
59	AT32	AT22	5790	8634	851	122.433524000000006
58	AT32	AT21	5790	4117	310	92.8944079999999985
57	AT32	AT13	5790	26980	1349	244.108305000000001
56	AT32	AT12	5790	25741	378	201.232355000000013
55	AT32	AT11	5790	5146	49	246.93330499999999
27	AT13	AT34	29142	1910	407	498.407151999999996
26	AT13	AT33	29142	3952	674	387.617759999999976
25	AT13	AT32	29142	4902	742	244.108305000000001
24	AT13	AT31	29142	8193	1943	186.420738
23	AT13	AT22	29142	8634	1831	158.630661000000003
22	AT13	AT21	29142	4117	1080	249.932873999999998
21	AT13	AT13	29142	26980	0	1.00000000000000003e-300
20	AT13	AT12	29142	25741	20164	45.7962720000000019
19	AT13	AT11	29142	5146	2301	84.2046660000000031
81	AT34	AT34	2184	1910	0	1.00000000000000003e-300
36	AT21	AT34	4897	1910	114	306.105824999999982
35	AT21	AT33	4897	3952	469	194.851668999999987
34	AT21	AT32	4897	4902	317	92.8944079999999985
33	AT21	AT31	4897	8193	328	151.777156999999988
32	AT21	AT22	4897	8634	1608	92.4079579999999936
31	AT21	AT21	4897	4117	0	1.00000000000000003e-300
30	AT21	AT13	4897	26980	1597	249.932873999999998
29	AT21	AT12	4897	25741	379	216.99473900000001
28	AT21	AT11	4897	5146	85	220.81193300000001
80	AT34	AT33	2184	3952	587	114.463250000000002
79	AT34	AT32	2184	4902	112	258.591197000000022
78	AT34	AT31	2184	8193	199	314.793199000000016
77	AT34	AT22	2184	8634	328	376.346670000000017
76	AT34	AT21	2184	4117	154	306.105824999999982
75	AT34	AT13	2184	26980	643	498.407151999999996
74	AT34	AT12	2184	25741	128	453.515594000000021
73	AT34	AT11	2184	5146	33	505.089539000000002
\.
