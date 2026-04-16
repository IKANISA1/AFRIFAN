-- ==========================================================================
-- AfriClub — Club Brand Identity & Social Media Profiles
-- ==========================================================================
-- Adds region, league, brand colors, nickname/brand identity,
-- official contact info, and social media URLs to the clubs table.
-- ==========================================================================

-- ── New columns ──
alter table public.african_football_clubs
  add column if not exists region                  text,
  add column if not exists league                  text,
  add column if not exists primary_brand_colors    text,
  add column if not exists nickname_brand_identity text,
  add column if not exists official_contact        text,
  add column if not exists facebook_url            text,
  add column if not exists x_twitter_url           text,
  add column if not exists instagram_url           text,
  add column if not exists tiktok_url              text,
  add column if not exists official_logo_url       text;

-- Index for region/league filtering
create index if not exists idx_afc_region on public.african_football_clubs (region);
create index if not exists idx_afc_league on public.african_football_clubs (league);

-- ==========================================================================
-- Upsert brand + social data for all 96 clubs
-- ==========================================================================

update public.african_football_clubs set
  region = v.region, league = v.league,
  primary_brand_colors = v.colors, nickname_brand_identity = v.nickname,
  official_contact = v.contact, facebook_url = v.fb,
  x_twitter_url = v.tw, instagram_url = v.ig,
  tiktok_url = v.tt, official_logo_url = v.logo,
  updated_at = now()
from (values
  ('Petro de Luanda','Southern Africa','Girabola','Yellow, Blue, Red','Petro / Os Tricolores','+244 222 324 095 (Office)','fb.com/petrodeluanda','x.com/petro_de_luanda','instagram.com/petro_de_luanda','tiktok.com/@petro_de_luanda','https://en.wikipedia.org/wiki/File:Petro_de_Luanda_logo.png'),
  ('Primeiro de Agosto','Southern Africa','Girabola','Red, Black','Os Avermelhados / D''Agosto','+244 222 321 445 (Office)','fb.com/ClubeDesportivo1deAgosto','x.com/cd_1deagosto','instagram.com/cd_1deagosto',null,'https://en.wikipedia.org/wiki/File:CD_Primeiro_de_Agosto_logo.png'),
  ('Mogas 90 FC','West Africa','Ligue 1 Bénin','Green, White','Mogas','Local FA Directory','fb.com/Mogas90FC',null,null,null,'https://fr.wikipedia.org/wiki/Fichier:Mogas_90_FC_logo.png'),
  ('ASPAC FC','West Africa','Ligue 1 Bénin','Blue, White','Les Requins Blancs','Corporate Board Line','fb.com/ASPACBénin',null,'instagram.com/aspac_fc',null,'https://fr.wikipedia.org/wiki/Fichier:ASPAC_FC_logo.png'),
  ('Township Rollers FC','Southern Africa','Botswana Premier League','Blue, Gold','Popa','+267 318 0134','fb.com/TownshipRollersFC','x.com/rollersfc','instagram.com/township_rollers',null,'https://en.wikipedia.org/wiki/File:Township_Rollers_FC_logo.png'),
  ('Gaborone United FC','Southern Africa','Botswana Premier League','Red, White','GU / The Money Machine','+267 390 0100','fb.com/GaboroneUnitedSC','x.com/GaboroneUnited1','instagram.com/gaboroneunited',null,'https://en.wikipedia.org/wiki/File:Gaborone_United_logo.png'),
  ('ASFA Yennenga','West Africa','Burkinabé Premier League','Yellow, Green','Les Étalons','Club Secretariat','fb.com/AsfaYennengaOfficiel','x.com/asfayennenga',null,null,'https://en.wikipedia.org/wiki/File:ASFA_Yennenga_logo.png'),
  ('Étoile Filante','West Africa','Burkinabé Premier League','Blue, White','L''Étoile / Les Stellistes','Club Secretariat','fb.com/EFO.Officiel',null,null,null,'https://en.wikipedia.org/wiki/File:Etoile_Filante_Ouagadougou_logo.png'),
  ('Vital''O FC','East Africa','Ligue A Burundi','Purple, White','Blues','Local FA Directory','fb.com/Vitalofcofficiel','x.com/VitaloFCOfficie','instagram.com/vitalofcofficiel',null,'https://en.wikipedia.org/wiki/File:Vital%27O_FC_logo.png'),
  ('Musongati FC','East Africa','Ligue A Burundi','Green, Yellow','Gazelles','Local FA Directory','fb.com/MusongatiFC','x.com/MusongatiFc',null,null,'https://en.wikipedia.org/wiki/File:Musongati_FC_logo.png'),
  ('Canon Yaoundé','West Africa','MTN Elite One','Green, Red','Kpa-Kum / Les Diables Rouges','+237 2 22 22 22 (Gen. Office)','fb.com/CanonSportifDeYaounde','x.com/CanonSportif','instagram.com/canonsportif',null,'https://en.wikipedia.org/wiki/File:Canon_Yaounde_logo.png'),
  ('Union Douala','West Africa','MTN Elite One','Green, White','Les Nassaras','Club Secretariat','fb.com/UnionSportiveDeDouala','x.com/usdofficiel','instagram.com/union_sportive_de_douala',null,'https://en.wikipedia.org/wiki/File:Union_Douala_logo.png'),
  ('Sporting Clube de Praia','West Africa','Campeonato Nacional','Green, White','Leões','Local FA Directory','fb.com/SportingClubeDRayon Sportsaia',null,null,null,'https://en.wikipedia.org/wiki/File:Sporting_Clube_da_Praia_logo.png'),
  ('FC Académica do Porto Novo','West Africa','Campeonato Nacional','Black, White','APN','Local FA Directory','fb.com/AcademicaPortoNovo',null,null,null,'https://pt.wikipedia.org/wiki/Ficheiro:Academica_Porto_Novo_logo.png'),
  ('AS Tempête Mocaf','Central Africa','CAR National League','Black, Red','Tempête','Local FA Directory','fb.com/ASTempeteMocaf',null,null,null,'https://fr.wikipedia.org/wiki/Fichier:AS_Tempete_Mocaf_logo.png'),
  ('Olympique Réal de Bangui','Central Africa','CAR National League','Green, White','Olympique','Local FA Directory','fb.com/OlympiqueRealBangui',null,null,null,'https://fr.wikipedia.org/wiki/Fichier:Olympique_Real_de_Bangui_logo.png'),
  ('Foullah Edifice FC','Central Africa','Ligue Nationale Chad','Blue, White','Foullah','Local FA Directory','fb.com/FoullahEdificeFC',null,null,null,'https://fr.wikipedia.org/wiki/Fichier:Foullah_Edifice_FC_logo.png'),
  ('AS Coton Chad','Central Africa','Ligue Nationale Chad','Green, White','Coton','Corporate Board Line','fb.com/ASCotonTchad',null,null,null,'https://fr.wikipedia.org/wiki/Fichier:AS_CotonTchad_logo.png'),
  ('Volcan Club','Indian Ocean','Championnat de Comores','Green, White','Volcan','Local FA Directory','fb.com/VolcanClubDeMoroni',null,null,null,'https://fr.wikipedia.org/wiki/Fichier:Volcan_Club_de_Moroni_logo.png'),
  ('Fomboni SC','Indian Ocean','Championnat de Comores','Blue, White','Fomboni','Local FA Directory','fb.com/FomboniClub',null,null,null,'https://en.wikipedia.org/wiki/File:Fomboni_FC_logo.png'),
  ('AC Léopards','Central Africa','Ligue 1 Congo','Green, White','Les Fauves du Niari','Club Secretariat','fb.com/ACLeopardsDeDolisie',null,null,null,'https://en.wikipedia.org/wiki/File:AC_Leopards_logo.png'),
  ('Étoile du Congo','Central Africa','Ligue 1 Congo','Green, Yellow','Les Diables Noirs','Club Secretariat','fb.com/EtoileDuCongo',null,null,null,'https://en.wikipedia.org/wiki/File:Etoile_du_Congo_logo.png'),
  ('AS Arta/Solar7','East Africa','Djibouti Premier League','Blue, White','Solar','Official FB Messenger','fb.com/ArtaSolar7','x.com/ArtaSolar7','instagram.com/artasolar7',null,'https://en.wikipedia.org/wiki/File:AS_Arta_Solar_7_logo.png'),
  ('AS Port','East Africa','Djibouti Premier League','Red, White','The Dockers','Port Authority Line','fb.com/ASPortDjibouti',null,null,null,'https://en.wikipedia.org/wiki/File:AS_Port_logo.png'),
  ('TP Mazembe','Central Africa','Linafoot','Black, White','Les Corbeaux (The Ravens)','+243 99 70 30 000','fb.com/TPMazembe','x.com/TPMazembe','instagram.com/tpmazembe_officiel','tiktok.com/@tpmazembe_officiel','https://en.wikipedia.org/wiki/File:TP_Mazembe_logo.png'),
  ('AS Vita Club','Central Africa','Linafoot','Green, Black','Les Dauphins Noirs','Club Secretariat','fb.com/ASVitaClubOfficiel','x.com/AsVitaOfficiel','instagram.com/asvitaclub',null,'https://en.wikipedia.org/wiki/File:AS_Vita_Club_logo.png'),
  ('Leones Vegetarianos FC','Central Africa','Liga Nacional','Green, White','Leones','Local FA Directory','fb.com/LeonesVegetarianosFC',null,null,null,'https://en.wikipedia.org/wiki/File:Leones_Vegetarianos_FC_logo.png'),
  ('Deportivo Mongomo','Central Africa','Liga Nacional','Red, White','Mongomo','Local FA Directory','fb.com/DeportivoMongomo',null,null,null,'https://en.wikipedia.org/wiki/File:Deportivo_Mongomo_logo.png'),
  ('Red Sea FC','East Africa','Eritrea Premier League','Red, White','Red Sea','Local FA Directory',null,null,null,null,'https://en.wikipedia.org/wiki/File:Red_Sea_FC_logo.png'),
  ('Asha FC','East Africa','Eritrea Premier League','Blue, White','Asha','Local FA Directory',null,null,null,null,'https://en.wikipedia.org/wiki/File:Asha_FC_logo.png'),
  ('Mbabane Highlanders','Southern Africa','Eswatini Premier League','Black, White','Inkunzi / Highlanders','Official FB Messenger','fb.com/MbabaneHighlandersFC','x.com/Highlanders_FC','instagram.com/mbabanehighlanders',null,'https://en.wikipedia.org/wiki/File:Mbabane_Highlanders_logo.png'),
  ('Mbabane Swallows','Southern Africa','Eswatini Premier League','Red, White','Umkhonto KaShaka','Official FB Messenger','fb.com/MbabaneSwallowsFC','x.com/MbabaneSwallows','instagram.com/mbabaneswallowsfc',null,'https://en.wikipedia.org/wiki/File:Mbabane_Swallows_logo.png'),
  ('Ethiopian Coffee SC','East Africa','Ethiopian Premier League','Maroon, Gold','The Baristas / Buna','+251 11 551 5555','fb.com/EthiopianCoffeeSC','x.com/EthioCoffeeSC','instagram.com/ethiopiancoffeesc','tiktok.com/@ethiopiancoffeesc','https://en.wikipedia.org/wiki/File:Ethiopian_Coffee_SC_logo.png'),
  ('St. George SC','East Africa','Ethiopian Premier League','Yellow, Red','Saints / Faresoch','+251 11 156 4444','fb.com/SaintGeorgeFC','x.com/SaintGeorgeFC','instagram.com/saintgeorgefc','tiktok.com/@saintgeorgefc_official','https://en.wikipedia.org/wiki/File:Saint_George_SC_logo.png'),
  ('CF Mounana','Central Africa','Championnat D1 Gabon','Blue, White','Mounana','Club Secretariat','fb.com/CFMounana','x.com/CF_Mounana','instagram.com/cfmounana',null,'https://en.wikipedia.org/wiki/File:CF_Mounana_logo.png'),
  ('AS Mangasport','Central Africa','Championnat D1 Gabon','Yellow, Green','Les Panthères','Corporate Board Line','fb.com/ASMangasport',null,null,null,'https://en.wikipedia.org/wiki/File:AS_Mangasport_logo.png'),
  ('Gambia Armed Forces','West Africa','GFF National Super League','Khaki, Green','Army Boys','Military Sports Dept.','fb.com/GAFFC',null,null,null,'https://en.wikipedia.org/wiki/File:Gambia_Armed_Forces_FC_logo.png'),
  ('Real de Banjul FC','West Africa','GFF National Super League','White, Red','Real','Official FB Messenger','fb.com/RealDeBanjulFC','x.com/RealDeBanjulFC','instagram.com/realdebanjulfc',null,'https://en.wikipedia.org/wiki/File:Real_de_Banjul_logo.png'),
  ('Asante Kotoko SC','West Africa','Ghana Premier League','Red, White','The Porcupine Warriors','Official WhatsApp Channel Link','fb.com/AsanteKotokoSportingClub','x.com/AsanteKotoko_SC','instagram.com/asantekotoko_sc','tiktok.com/@asantekotoko_sc','https://en.wikipedia.org/wiki/File:Asante_Kotoko_SC_logo.png'),
  ('Accra Hearts of Oak','West Africa','Ghana Premier League','Red, Yellow, Blue','The Phobians','Official WhatsApp Channel Link','fb.com/AccraHeartsofOak','x.com/HeartsOfOakGH','instagram.com/accraheartsofoak','tiktok.com/@accraheartsofoak','https://en.wikipedia.org/wiki/File:Accra_Hearts_of_Oak_SC_logo.png'),
  ('Hafia FC','West Africa','Ligue 1 Guinea','Green, White','Les Aiglons (Babata)','+224 622 22 22 22 (Est.)','fb.com/HafiaFC','x.com/HafiaFCOfficiel','instagram.com/hafiafcofficiel',null,'https://en.wikipedia.org/wiki/File:Hafia_FC_logo.png'),
  ('Horoya AC','West Africa','Ligue 1 Guinea','Red, White','HAC / Matam Boys','Official FB Messenger','fb.com/HoroyaAthletiqueClub','x.com/HACofficiel','instagram.com/horoyaac','tiktok.com/@horoyaac','https://en.wikipedia.org/wiki/File:Horoya_AC_logo.png'),
  ('Sport Bissau e Benfica','West Africa','Liga Nacional Guinea-Bissau','Red, White','Águias de Bissau','Local FA Directory','fb.com/SportBissaueBenfica',null,null,null,'https://pt.wikipedia.org/wiki/Ficheiro:Sport_Bissau_e_Benfica_logo.png'),
  ('Sporting Bissau','West Africa','Liga Nacional Guinea-Bissau','Green, White','Leões','Local FA Directory','fb.com/SportingClubeDeBissau',null,null,null,'https://pt.wikipedia.org/wiki/Ficheiro:Sporting_Clube_de_Bissau_logo.png'),
  ('ASEC Mimosas','West Africa','Ligue 1 Côte d''Ivoire','Yellow, Black','Les Mimosas','+225 22 44 44 44','fb.com/ASECMimosas','x.com/ASECMimosas','instagram.com/asecmimosas','tiktok.com/@asecmimosas','https://en.wikipedia.org/wiki/File:ASEC_Mimosas_logo.png'),
  ('Africa Sports National','West Africa','Ligue 1 Côte d''Ivoire','Green, Red','Les Aiglons / Oyé','Club Secretariat','fb.com/AfricaSportsNational','x.com/AfricaSports_','instagram.com/africasportsnational',null,'https://en.wikipedia.org/wiki/File:Africa_Sports_National_logo.png'),
  ('Gor Mahia FC','East Africa','FKF Premier League','Green, White','K''Ogalo','Official FB Messenger','fb.com/GorMahiaFC','x.com/OfficialGMFC','instagram.com/officialgormahia','tiktok.com/@gormahiafcofficial','https://en.wikipedia.org/wiki/File:Gor_Mahia_FC_logo.png'),
  ('AFC Leopards','East Africa','FKF Premier League','Blue, White','Ingwe (Leopards)','Official FB Messenger','fb.com/AFCLeopardsSC','x.com/AFCLeopards','instagram.com/afcleopards','tiktok.com/@afcleopards','https://en.wikipedia.org/wiki/File:AFC_Leopards_logo.png'),
  ('Lesotho Mounted Police','Southern Africa','Lesotho Premier League','Red, Blue','LMP / Simunye','Police Sports Dept.','fb.com/LMPFC',null,null,null,'https://en.wikipedia.org/wiki/File:Lesotho_Mounted_Police_Service_FC_logo.png'),
  ('Bantu FC','Southern Africa','Lesotho Premier League','Black, Gold','A Matšo Matebele','Official FB Messenger','fb.com/BantuFC','x.com/Bantu_FC','instagram.com/bantu_fc',null,'https://en.wikipedia.org/wiki/File:Bantu_FC_logo.png'),
  ('LISCR FC','West Africa','LNFA Super League','Blue, White','The Shipping Boys','Corporate Board Line','fb.com/LISCRFC','x.com/LISCRFC','instagram.com/liscrfc',null,'https://en.wikipedia.org/wiki/File:LISCR_FC_logo.png'),
  ('Mighty Barrolle FC','West Africa','LNFA Super League','Red, White','The Rollers','Official FB Messenger','fb.com/MightyBarrolleSportsAssociation',null,null,null,'https://en.wikipedia.org/wiki/File:Mighty_Barrolle_logo.png'),
  ('Fosa Juniors FC','Indian Ocean','Pro League Madagascar','Orange, Black','Fosa','Official FB Messenger','fb.com/FosaJuniorsFC',null,'instagram.com/fosajuniorsfc',null,'https://en.wikipedia.org/wiki/File:Fosa_Juniors_FC_logo.png'),
  ('CNAPS Sport','Indian Ocean','Pro League Madagascar','Yellow, Green','CNAPS','Corporate Board Line','fb.com/CNaPSSportFootball',null,null,null,'https://en.wikipedia.org/wiki/File:CNaPS_Sport_logo.png'),
  ('Nyasa Big Bullets FC','Southern Africa','TNM Super League','Red, White','The People''s Team','Official FB Messenger','fb.com/NyasaBigBullets','x.com/NyasaBigBullets','instagram.com/nyasabigbullets',null,'https://en.wikipedia.org/wiki/File:Nyasa_Big_Bullets_FC_logo.png'),
  ('Mighty Wanderers FC','Southern Africa','TNM Super League','Blue, White','The Nomads','Official FB Messenger','fb.com/MightyWanderersFC','x.com/MightyWanderers','instagram.com/mightywanderersfc',null,'https://en.wikipedia.org/wiki/File:Mighty_Wanderers_FC_logo.png'),
  ('Djoliba AC','West Africa','Première Division Mali','Red, Green','Les Rouges','Club Secretariat','fb.com/DjolibaAthleticClub','x.com/DjolibaAC','instagram.com/djoliba_ac',null,'https://en.wikipedia.org/wiki/File:Djoliba_AC_logo.png'),
  ('Stade Malien','West Africa','Première Division Mali','White, Blue','Les Blancs','Club Secretariat','fb.com/StadeMalienDeBamako','x.com/StadeMalien','instagram.com/stademalien',null,'https://en.wikipedia.org/wiki/File:Stade_Malien_logo.png'),
  ('FC Nouadhibou','West Africa','Ligue 1 Mauritanienne','Orange, Blue','Le Club Orange','Official FB Messenger','fb.com/FCNouadhibou','x.com/FCNouadhibou','instagram.com/fcnouadhibou',null,'https://en.wikipedia.org/wiki/File:FC_Nouadhibou_logo.png'),
  ('ASC Ksar','West Africa','Ligue 1 Mauritanienne','Green, White','Ksar','Local FA Directory','fb.com/ASCKsar',null,null,null,'https://en.wikipedia.org/wiki/File:ASC_Ksar_logo.png'),
  ('AS Port-Louis 2000','Indian Ocean','MFA League','Green, Red','Port-Louis','Local FA Directory','fb.com/ASPortLouis2000',null,null,null,'https://en.wikipedia.org/wiki/File:AS_Port-Louis_2000_logo.png'),
  ('Pamplemousses SC','Indian Ocean','MFA League','Blue, White','Pamplemousses','Local FA Directory','fb.com/PamplemoussesSC',null,null,null,'https://en.wikipedia.org/wiki/File:Pamplemousses_SC_logo.png'),
  ('Costa do Sol FC','Southern Africa','Moçambola','Yellow, Blue','Canarinhos (Canaries)','+258 21 414 414','fb.com/ClubeDeDesportosDaCostaDoSol','x.com/cdcostadosol','instagram.com/costadosoloficial',null,'https://en.wikipedia.org/wiki/File:CD_Costa_do_Sol_logo.png'),
  ('UD Songo FC','Southern Africa','Moçambola','Blue, White','Os Hidroeléctricos','Corporate Board Line','fb.com/UDSongo',null,'instagram.com/udsongo',null,'https://en.wikipedia.org/wiki/File:UD_Songo_logo.png'),
  ('African Stars FC','Southern Africa','Namibia Premier League','Red, White','Starlile / Okaserandu','Official FB Messenger','fb.com/AfricanStarsFC','x.com/AfricanStarsFC','instagram.com/africanstarsfc',null,'https://en.wikipedia.org/wiki/File:African_Stars_FC_logo.png'),
  ('Black Africa FC','Southern Africa','Namibia Premier League','Black, Red','The Lively Lions','Official FB Messenger','fb.com/BlackAfricaSportsClub',null,null,null,'https://en.wikipedia.org/wiki/File:Black_Africa_FC_logo.png'),
  ('Sahel SC','West Africa','Championnat du Niger','Green, Yellow','Les Vert et Jaune','Local FA Directory','fb.com/SahelSC',null,null,null,'https://en.wikipedia.org/wiki/File:Sahel_SC_logo.png'),
  ('Espoir FC de Zinder','West Africa','Championnat du Niger','White, Blue','L''Espoir','Local FA Directory',null,null,null,null,'https://fr.wikipedia.org/wiki/Fichier:Espoir_FC_Zinder_logo.png'),
  ('Kano Pillars FC','West Africa','Nigeria Premier Football League','Green, Yellow','Sai Masu Gida','Official Twitter DM','fb.com/KanoPillarsFC','x.com/pillarsfc','instagram.com/kanopillarsfc',null,'https://en.wikipedia.org/wiki/File:Kano_Pillars_FC_logo.png'),
  ('Enyimba FC','West Africa','Nigeria Premier Football League','Blue, White','The People''s Elephant','Official Twitter DM','fb.com/EnyimbaFootballClub','x.com/EnyimbaFC','instagram.com/enyimbafc','tiktok.com/@enyimbafc_','https://en.wikipedia.org/wiki/File:Enyimba_International_F.C._logo.png'),
  ('Rayon Sports FC','East Africa','Rwanda Premier League','Black, White','The Army Boys / Lions','Military Sports Dept.','fb.com/Rayon SportsFCRwanda','x.com/Rayon SportsFCOfficial','instagram.com/Rayon Sportsfc_official','tiktok.com/@Rayon Sportsfc_official','https://en.wikipedia.org/wiki/File:Rayon Sports_FC_logo.png'),
  ('Rayon Sports FC','East Africa','Rwanda Premier League','Blue, White','Gikundiro (The Beloved)','Official FB Messenger','fb.com/RayonSportsOfficial','x.com/rayon_sports','instagram.com/rayonsports_official','tiktok.com/@rayonsports','https://en.wikipedia.org/wiki/File:Rayon_Sports_FC_logo.png'),
  ('Sporting Praia Cruz','Central Africa','Campeonato STP','Green, White','Leões do Mar','Local FA Directory',null,null,null,null,'https://pt.wikipedia.org/wiki/Ficheiro:Sporting_Praia_Cruz_logo.png'),
  ('FC Porto Real','Central Africa','Campeonato STP','Blue, White','Porto Real','Local FA Directory',null,null,null,null,'https://pt.wikipedia.org/wiki/Ficheiro:FC_Porto_Real_logo.png'),
  ('ASC Jaraaf','West Africa','Ligue 1 Sénégal','Green, White','Les Médinois','Club Secretariat','fb.com/ASCJaraaf','x.com/ASCJaraaf','instagram.com/ascjaraafofficiel',null,'https://en.wikipedia.org/wiki/File:ASC_Jaraaf_logo.png'),
  ('Casa Sports','West Africa','Ligue 1 Sénégal','Green, White','Allez Casa / Zèbres','Official FB Messenger','fb.com/CasaSportsOfficiel','x.com/CasaSports_','instagram.com/casasports_officiel',null,'https://en.wikipedia.org/wiki/File:Casa_Sports_logo.png'),
  ('St. Michel United FC','Indian Ocean','Seychelles National Football League','Green, White','Saints','Local FA Directory','fb.com/StMichelUnited',null,null,null,'https://en.wikipedia.org/wiki/File:St_Michel_United_FC_logo.png'),
  ('Anse Reunion FC','Indian Ocean','Seychelles National Football League','Yellow, Blue','Anse','Local FA Directory',null,null,null,null,'https://en.wikipedia.org/wiki/File:Anse_Reunion_FC_logo.png'),
  ('East End Lions FC','West Africa','Sierra Leone Premier League','Red, Black','The Killers','Official FB Messenger','fb.com/EastEndLionsFC','x.com/EELions','instagram.com/eastendlionsfc',null,'https://en.wikipedia.org/wiki/File:East_End_Lions_logo.png'),
  ('Kallon FC','West Africa','Sierra Leone Premier League','Green, White','The Cavaliers','Official FB Messenger','fb.com/FCKallon','x.com/FCKallon','instagram.com/fckallon',null,'https://en.wikipedia.org/wiki/File:FC_Kallon_logo.png'),
  ('Banadir Stars','East Africa','Somalia Premier League','Blue, White','Stars','Local FA Directory','fb.com/MogadishuCityClub','x.com/MogadishuCity','instagram.com/mogadishucityclub',null,'https://en.wikipedia.org/wiki/File:Mogadishu_City_Club_logo.png'),
  ('Elman FC','East Africa','Somalia Premier League','Yellow, Blue','The Peace Builders','Official FB Messenger','fb.com/ElmanFC','x.com/ElmanFC','instagram.com/elman_fc',null,'https://en.wikipedia.org/wiki/File:Elman_FC_logo.png'),
  ('Kaizer Chiefs FC','Southern Africa','DStv Premiership','Gold, Black','Amakhosi','+27 11 941 1465','fb.com/KaizerChiefs','x.com/KaizerChiefs','instagram.com/kcfcofficial','tiktok.com/@kcfcofficial','https://en.wikipedia.org/wiki/File:Kaizer_Chiefs_logo.png'),
  ('Orlando Pirates FC','Southern Africa','DStv Premiership','Black, White','The Buccaneers (Bucs)','+27 11 483 1730','fb.com/OrlandoPirates','x.com/orlandopirates','instagram.com/orlandopirates','tiktok.com/@orlandopirates','https://en.wikipedia.org/wiki/File:Orlando_Pirates_logo.png'),
  ('Atlabara FC','East Africa','South Sudan National League','Yellow, Blue','Atlabara','Local FA Directory','fb.com/AtlabaraFC',null,null,null,'https://en.wikipedia.org/wiki/File:Atlabara_FC_logo.png'),
  ('Al-Hilal Juba FC','East Africa','South Sudan National League','Blue, White','The Sun','Local FA Directory','fb.com/AlHilalJuba',null,null,null,'https://en.wikipedia.org/wiki/File:Al-Hilal_Juba_logo.png'),
  ('Young Africans (Yanga)','East Africa','NBC Premier League','Green, Yellow','Yanga / Wananchi','+255 750 416 842 (App)','fb.com/YangaSC','x.com/yangasc1935','instagram.com/yangasc','tiktok.com/@yangasc','https://en.wikipedia.org/wiki/File:Young_Africans_S.C._logo.png'),
  ('Simba SC','East Africa','NBC Premier League','Red, White','Wekundu wa Msimbazi','+255 765 179 991 (Media)','fb.com/SimbaSCTanzania','x.com/SimbaSCTanzania','instagram.com/simbasctanzania','tiktok.com/@simbasctanzania','https://en.wikipedia.org/wiki/File:Simba_SC_logo.png'),
  ('ASKO de Kara','West Africa','Championnat du Togo','Yellow, Green','Les Kondonas','Official FB Messenger','fb.com/ASKOdeKara','x.com/ASKOdeKara','instagram.com/askodekara',null,'https://en.wikipedia.org/wiki/File:ASKO_Kara_logo.png'),
  ('Maranatha FC','West Africa','Championnat du Togo','Red, White','Les Messagers','Local FA Directory','fb.com/MaranathaFC',null,null,null,'https://en.wikipedia.org/wiki/File:Maranatha_FC_logo.png'),
  ('SC Villa','East Africa','Uganda Premier League','Blue, Red','The Jogoos','Official Twitter DM','fb.com/SCVillaJogoo','x.com/SCVillaJogoo','instagram.com/scvillajogoo','tiktok.com/@scvillajogoo','https://en.wikipedia.org/wiki/File:SC_Villa_logo.png'),
  ('Express FC','East Africa','Uganda Premier League','Red, White','The Red Eagles','Official Twitter DM','fb.com/ExpressFC','x.com/ExpressFCUganda','instagram.com/expressfcuganda',null,'https://en.wikipedia.org/wiki/File:Express_FC_logo.png'),
  ('Nkana FC','Southern Africa','MTN Super League','Red, White','Kalampa / Red Devils','Official FB Messenger','fb.com/NkanaFCOfficial','x.com/NkanaFCOfficial','instagram.com/nkanafcofficial',null,'https://en.wikipedia.org/wiki/File:Nkana_FC_logo.png'),
  ('ZESCO United FC','Southern Africa','MTN Super League','Green, Orange','Zega Mambo','Corporate Board Line','fb.com/ZescoUnitedFC','x.com/ZescoUnitedFC','instagram.com/zescounitedfc','tiktok.com/@zescounitedfc','https://en.wikipedia.org/wiki/File:ZESCO_United_FC_logo.png'),
  ('Dynamos FC','Southern Africa','ZPSL','Blue, White','DeMbare / Glamour Boys','Official FB Messenger','fb.com/DynamosFC','x.com/DynamosFC','instagram.com/dynamosfc_',null,'https://en.wikipedia.org/wiki/File:Dynamos_FC_logo.png'),
  ('Highlanders FC','Southern Africa','ZPSL','Black, White','Bosso / Tshilamoya','Official FB Messenger','fb.com/HighlandersFC','x.com/HighlandersBosso','instagram.com/highlandersfc_',null,'https://en.wikipedia.org/wiki/File:Highlanders_FC_logo.png')
) as v(name, region, league, colors, nickname, contact, fb, tw, ig, tt, logo)
where african_football_clubs.club_name = v.name;

-- Verify update count
do $$
declare
  updated_count int;
begin
  select count(*) into updated_count
  from public.african_football_clubs
  where region is not null;
  raise notice 'Updated % clubs with brand/social data', updated_count;
end $$;
