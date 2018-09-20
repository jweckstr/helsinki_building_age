"""
Script to import data from shapefiles and add to postgis DB
run geoserver: >%GEOSERVER_HOME%\bin\startup
D:\Program Files (x86)\GeoServer 2.13.0\bin
http://localhost:8082/geoserver/
admin
geoserver



Enable cors to get stuff working
"""
import pandas as pd
import geopandas as gpd
import os
import numpy

data_folder = "D:\YIMBY\GISprojekt\Helsingfors byggnader genom tiderna"
geoserver_folder = "D:\Program Files (x86)\GeoServer 2.13.0\data_dir\data\hfors"
# "rakrek_1700_dump.shp",
fnames = ["rakrek_1700_dump.shp", "rakrek_1800_dump.shp", "rakrek_1878_kanta.shp", "rakrek_dump.shp",
          "rakrek_1932.shp", "rakrek_1943_kanta.shp", "rakrek_1950_kanta.shp", "rakrek_1964_kanta.shp", "rakrek_1969_kanta.shp",
          "rakrek_1976_kanta.shp", "rakrek_1988_kanta.shp", "rakrek_2012_kanta.shp", "rakrek_2017_kanta.shp"]

rakvuos_alku_defaults = [1721, 1750, 1800, 1800, 1800, 1933, 1944, 1951, 1965, 1970, 1977, 1989, 2013]
rakvuos_loppu_default = [1850, 1932, 1932, 1932, 1932, 1943, 1950, 1964, 1969, 1976, 1988, 2012, 2017]
purvuos_loppu_default = [1850, 1932, 1932, 1932, None, None, None, None, None, None, None, None, None]


def rakvuos(rakvuosis, rakvuoskoms, rakvuos_alku_default, rakvuos_loppu_default, alku=True):
    rakvuosi_alku = []
    rakvuosi_loppu = []
    for rakvuosi, rakvuoskom in zip(rakvuosis, rakvuoskoms):
        if not numpy.isnan(rakvuosi) and not rakvuosi == 9999:

            rakvuosi_alku.append(rakvuosi)
            rakvuosi_loppu.append(rakvuosi)
        elif isinstance(rakvuoskom, unicode) and len(rakvuoskom) >= 5:
                if rakvuoskom[0] == '<':
                    rakvuosi_alku.append(rakvuos_alku_default)
                    rakvuosi_loppu.append(rakvuoskom[1:5])
                elif rakvuoskom[0] == '>':
                    rakvuosi_alku.append(rakvuoskom[1:5])
                    rakvuosi_loppu.append(rakvuos_loppu_default)
                elif rakvuoskom[4] == '-':

                    rakvuosi_alku.append(rakvuoskom[0:4])
                    if 'l' in rakvuoskom[5:9]:
                        rakvuosi_loppu.append(rakvuoskom[0:3]+'9')
                    else:
                        rakvuosi_loppu.append(rakvuoskom[5:9])
                else:
                    rakvuosi_alku.append(rakvuos_alku_default)
                    rakvuosi_loppu.append(rakvuos_loppu_default)
        else:
            rakvuosi_alku.append(rakvuos_alku_default)
            rakvuosi_loppu.append(rakvuos_loppu_default)
    if alku:
        return [float(x) for x in rakvuosi_alku]
    else:
        return [float(x) for x in rakvuosi_loppu]


def purvuos(purvuosis, purvuoskoms, purvuos_alku_defaults, purvuos_loppu_default, alku=True):
    purvuosi_alku = []
    purvuosi_loppu = []
    for purvuosi, purvuoskom, purvuos_alku_default in zip(purvuosis, purvuoskoms, purvuos_alku_defaults):
        if not numpy.isnan(purvuosi) and not purvuosi == 9999:

            purvuosi_alku.append(purvuosi)
            purvuosi_loppu.append(purvuosi)
        elif isinstance(purvuoskom, unicode) and len(purvuoskom) >= 5:
                if purvuoskom[0] == '<':
                    purvuosi_alku.append(purvuos_alku_default)
                    purvuosi_loppu.append(purvuoskom[1:5])
                elif purvuoskom[0] == '>':
                    purvuosi_alku.append(purvuoskom[1:5])
                    purvuosi_loppu.append(purvuos_loppu_default)
                elif purvuoskom[4] == '-':
                    purvuosi_alku.append(purvuoskom[0:4])
                    if 'l' in purvuoskom[5:9]:
                        purvuosi_loppu.append(purvuoskom[0:3]+'9')
                    else:
                        purvuosi_loppu.append(purvuoskom[5:9])
                else:
                    purvuosi_alku.append(numpy.nan)
                    purvuosi_loppu.append(numpy.nan)
        else:
            purvuosi_alku.append(numpy.nan)
            purvuosi_loppu.append(numpy.nan)
    if alku:
        return [float(x) for x in purvuosi_alku]
    else:
        return [float(x) for x in purvuosi_loppu]


def prepare_intersections(intersections):
    intersections = intersections.loc[intersections['purvuosi_older'].isnull()]
    intersections = intersections.loc[intersections['purvuoskom_older'].isnull()]

    intersections = intersections.assign(purvuosi_alku_right=lambda x: x.rakvuosi_alku_right-2)
    intersections = intersections.assign(purvuosi_loppu_right=lambda x: x.rakvuosi_loppu_right-2)

    intersections['purvuosi_alku_right'] = intersections[['purvuosi_alku_right', 'rakvuosi_loppu_older']].max(axis=1)
    #print(intersections.loc[intersections['rakvuoskom_right'] == "<1912"])

    intersections = intersections[['index1', 'purvuosi_alku_right', 'purvuosi_loppu_right', 'rakvuoskom_right']]
    intersections_max = intersections.copy()
    intersections_max = intersections_max.set_index('index1', drop=True)
    intersections_max = intersections_max.groupby(intersections_max.index).max()

    intersections_min = intersections.groupby(level=0).min()
    #print(intersections_min.loc[intersections_min['rakvuoskom_right'] == "<1912"])
    #print(intersections_max.loc[intersections_max['rakvuoskom_right'] == "<1912"])

    return intersections_min, intersections_max


def get_purvuosi_for_overlapping_building(older_df, master_df):
    columns = list(master_df.columns.values)

    older_df_shrinked = older_df.copy()
    older_df_shrinked.geometry = older_df.geometry.scale(xfact=0.98, yfact=0.98, zfact=1.0)
    master_df['index1'] = master_df.index
    intersections = gpd.sjoin(older_df_shrinked, master_df, how="inner", op='intersects', lsuffix="older", rsuffix="right")
    intersections_min, intersections_max = prepare_intersections(intersections)

    older_df = older_df.join(intersections_min, how="left")
    # set purvuosis based on overlapping building
    older_df.loc[older_df['purvuosi'].isnull() & older_df['purvuoskom'].isnull(), 'purvuosi_alku'] = older_df['purvuosi_alku_right']
    older_df.loc[older_df['purvuosi'].isnull() & older_df['purvuoskom'].isnull(), 'purvuosi_loppu'] = older_df['purvuosi_loppu_right']

    # fix the younger building's building start year if given by <

    master_df = master_df.set_index('index1', drop=True)

    master_df = master_df.join(intersections_max, how="left")

    master_df.loc[master_df['purvuosi_alku_right'].notnull() & master_df['rakvuosi'].isnull() & master_df['rakvuoskom'].str.match('<'), 'rakvuosi_alku'] = master_df['purvuosi_alku_right']

    # ignore the buildings that still exist, enforced by 'Kiinteisto' (small overlaps would otherwise be problematic)
    older_df.loc[~older_df['Kiinteisto'].isnull() & older_df['purvuosi'].isnull() & older_df['purvuoskom'].isnull(), 'purvuosi_alku'] = numpy.nan
    older_df.loc[~older_df['Kiinteisto'].isnull() & older_df['purvuosi'].isnull() & older_df['purvuoskom'].isnull(), 'purvuosi_loppu'] = numpy.nan

    return older_df[columns], master_df[columns]

if True:
    master_df = None
    for fname, alku_default, loppu_default, purvuos_default in reversed(zip(fnames, rakvuos_alku_defaults, rakvuos_loppu_default, purvuos_loppu_default)):
        print(fname)
        df = gpd.read_file(os.path.join(data_folder, fname))

        df.crs = {'init': 'epsg:3879'}
        df = df.dropna(subset=['geometry'])

        df['geometry'] = df['geometry'].buffer(0)
        df[['rakvuosi', 'purvuosi']] = df[['rakvuosi', 'purvuosi']].apply(pd.to_numeric)

        df = df.assign(rakvuosi_alku=lambda x: rakvuos(x.rakvuosi, x.rakvuoskom, alku_default, loppu_default, alku=True))
        df = df.assign(rakvuosi_loppu=lambda x: rakvuos(x.rakvuosi, x.rakvuoskom, alku_default, loppu_default, alku=False))
        df[['rakvuosi_alku', 'rakvuosi_loppu']] = df[['rakvuosi_alku', 'rakvuosi_loppu']].apply(pd.to_numeric)

        df = df.assign(purvuosi_alku=lambda x: purvuos(x.purvuosi, x.purvuoskom, x.rakvuosi_loppu, purvuos_default, alku=True))
        df = df.assign(purvuosi_loppu=lambda x: purvuos(x.purvuosi, x.purvuoskom, x.rakvuosi_loppu, purvuos_default, alku=False))
        df[['purvuosi_alku', 'purvuosi_loppu']] = df[['purvuosi_alku', 'purvuosi_loppu']].apply(pd.to_numeric)
        #print(df.loc[df['lisatiedot'] == "__tama__"])
        #print(master_df.loc[master_df['lisatiedot'] == "__tama__"])


        if master_df is not None:

            df, master_df = get_purvuosi_for_overlapping_building(df, master_df)
            if fname in ["rakrek_1700_dump.shp", "rakrek_1800_dump.shp", "rakrek_1878_kanta.shp", "rakrek_dump.shp"]:
                df.loc[df['purvuosi_alku'].isnull(), 'purvuosi_alku'] = df['rakvuosi_loppu']
                df.loc[df['purvuosi_loppu'].isnull(), 'purvuosi_loppu'] = loppu_default
                df.loc[df['purvuosi_loppu'] > loppu_default, 'purvuosi_alku'] = df['rakvuosi_loppu']
                df.loc[df['purvuosi_loppu'] > loppu_default, 'purvuosi_loppu'] = loppu_default
            master_df = master_df.append(df)

        else:
            master_df = df
        master_df.reset_index(drop=True, inplace=True)
    master_df.loc[master_df['purvuosi_alku'] < master_df['rakvuosi_loppu'], 'rakvuosi_loppu'] = master_df['purvuosi_alku']

    master_df.loc[master_df['lisatiedot'].isnull(), 'lisatiedot'] = ''
    master_df['lisatiedot'] = master_df['lisatiedot'].apply(lambda x: x if '__k__:' in x else x+'__k__:')
    master_df['kuvat'] = master_df['lisatiedot'].apply(lambda x: x.split('__k__:')[1])
    master_df['lisatiedot'] = master_df['lisatiedot'].apply(lambda x: x.split('__k__:')[0])


    master_df = master_df.to_crs({'init': 'epsg:4326'})
    master_df.to_file(driver='ESRI Shapefile', filename=os.path.join(geoserver_folder, "all_merged.shp"))
    master_df.to_file(driver='ESRI Shapefile', filename=os.path.join(data_folder, "all_merged.shp"))

for fname, folder in zip(["vesi_all_wgs.shp", "liikenne_kaikki.shp", "land.shp"],
                         [os.path.join(data_folder, "vesi"), data_folder, os.path.join(data_folder, "vesi")]):
    df = gpd.read_file(os.path.join(folder, fname))
    df.crs = {'init': 'epsg:4326'}
    df = df.dropna(subset=['geometry'])

    #df['geometry'] = df['geometry'].buffer(0)
    df.to_file(driver='ESRI Shapefile', filename=os.path.join(geoserver_folder, fname))

