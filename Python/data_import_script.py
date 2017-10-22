"""
Script to import data from shapefiles and add to postgis DB
run geoserver: >%GEOSERVER_HOME%\bin\startup

Enable cors to get stuff working
"""
import pandas as pd
import geopandas as gpd
import os
import numpy

data_folder = "D:\YIMBY\GISprojekt\Helsingfors byggnader genom tiderna"
geoserver_folder = "D:\GeoServer2.11.2\data_dir\data\hfors"
# "rakrek_1700_dump.shp",
fnames = ["rakrek_1700_dump.shp", "rakrek_1800_dump.shp", "rakrek_1878_kanta.shp", "rakrek_dump.shp",
          "rakrek_1932.shp", "rakrek_1943_kanta.shp", "rakrek_1950_kanta.shp", "rakrek_1964_kanta.shp", "rakrek_1969_kanta.shp",
          "rakrek_1976_kanta.shp", "rakrek_1988_kanta.shp", "rakrek_2012_kanta.shp"]

rakvuos_alku_defaults = [1700, 1700, 1800, 1800, 1800, 1933, 1944, 1951, 1965, 1970, 1977, 1989]
rakvuos_loppu_default = [1810, 1932, 1932, 1932, 1932, 1943, 1950, 1964, 1969, 1976, 1988, 2017]


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
# TODO: kolla att purvuos > rakvuos


def purvuos(purvuosis, purvuoskoms, purvuos_alku_defaults, purvuos_loppu_default,alku=True):
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


def get_purvuosi_for_overlapping_building(new_df, master_df):
    columns = list(new_df.columns.values) #+ ['purvuosi_alku_right', 'purvuosi_loppu_right']

    #intersections = new_df['geometry'].intersection(master_df['geometry'])
    new_df_shrinked = new_df.copy()
    new_df_shrinked.geometry = new_df.geometry.scale(xfact=0.98, yfact=0.98, zfact=1.0)
    intersections = gpd.sjoin(new_df_shrinked, master_df, how="inner", op='intersects')

    """
    new_df["old_area"] = new_df['geometry'].area

    new_df["old_index"] = new_df.index
    #print(gpd.sjoin(new_df, master_df, how="inner", op='intersects').index)

    intersections = gpd.overlay(new_df, master_df, how='intersection')

    intersections = intersections.assign(purvuosi_alku_right=lambda x: x.rakvuosi_alku_2-2)
    intersections = intersections.assign(purvuosi_loppu_right=lambda x: x.rakvuosi_loppu_2-2)
    intersections["intersecting_area"] = intersections['geometry'].area
    intersections["area_ratio"] = intersections["intersecting_area"]/intersections["old_area"]

    intersections = intersections.set_index(['old_index'])
    pd.set_option('display.float_format', lambda x: '%.3f' % x)
    intersections = intersections.loc[intersections['area_ratio'] >= 0.01]

    #print(intersections[['area_ratio', 'intersecting_area', 'old_area', 'purvuosi_alku_right', 'purvuosi_loppu_right']])
    #exit()
    intersections = intersections[['purvuosi_alku_right', 'purvuosi_loppu_right']]

    intersections = intersections.groupby(level=0).min()

    new_df = new_df.join(intersections, how="left")
    """
    intersections = intersections.loc[intersections['purvuosi_left'].isnull()]
    intersections = intersections.loc[intersections['purvuoskom_left'].isnull()]

    #print(intersections)
    #exit()
    intersections = intersections.assign(purvuosi_alku_right=lambda x: x.rakvuosi_alku_right-2)
    intersections = intersections.assign(purvuosi_loppu_right=lambda x: x.rakvuosi_loppu_right-2)

    intersections = intersections[['purvuosi_alku_right', 'purvuosi_loppu_right']]
    intersections = intersections.groupby(level=0).min()


    new_df = new_df.join(intersections, how="left")

    new_df.loc[new_df['purvuosi'].isnull() & new_df['purvuoskom'].isnull(), 'purvuosi_alku'] = new_df['purvuosi_alku_right']
    new_df.loc[new_df['purvuosi'].isnull() & new_df['purvuoskom'].isnull(), 'purvuosi_loppu'] = new_df['purvuosi_loppu_right']

    new_df.loc[~new_df['Kiinteisto'].isnull(), 'purvuosi_alku'] = numpy.nan
    new_df.loc[~new_df['Kiinteisto'].isnull(), 'purvuosi_loppu'] = numpy.nan

    return new_df[columns]


master_df = None
for fname, alku_default, loppu_default in reversed(zip(fnames, rakvuos_alku_defaults, rakvuos_loppu_default)):
    print(fname)
    df = gpd.read_file(os.path.join(data_folder, fname))

    df.crs = {'init': 'epsg:3879'}
    df = df.dropna(subset=['geometry'])

    df['geometry'] = df['geometry'].buffer(0)
    df[['rakvuosi', 'purvuosi']] = df[['rakvuosi', 'purvuosi']].apply(pd.to_numeric)

    df = df.assign(rakvuosi_alku=lambda x: rakvuos(x.rakvuosi, x.rakvuoskom, alku_default, loppu_default, alku=True))
    df = df.assign(rakvuosi_loppu=lambda x: rakvuos(x.rakvuosi, x.rakvuoskom, alku_default, loppu_default, alku=False))
    df[['rakvuosi_alku', 'rakvuosi_loppu']] = df[['rakvuosi_alku', 'rakvuosi_loppu']].apply(pd.to_numeric)

    df = df.assign(purvuosi_alku=lambda x: purvuos(x.purvuosi, x.purvuoskom, x.rakvuosi_loppu, 2012, alku=True))
    df = df.assign(purvuosi_loppu=lambda x: purvuos(x.purvuosi, x.purvuoskom, x.rakvuosi_loppu, 2012, alku=False))
    df[['purvuosi_alku', 'purvuosi_loppu']] = df[['purvuosi_alku', 'purvuosi_loppu']].apply(pd.to_numeric)

    if master_df is not None:

        df = get_purvuosi_for_overlapping_building(df, master_df)
        if fname in ["rakrek_1700_dump.shp", "rakrek_1800_dump.shp", "rakrek_1878_kanta.shp", "rakrek_dump.shp"]:
            df.loc[df['purvuosi_alku'].isnull(), 'purvuosi_alku'] = df['rakvuosi_loppu']
            df.loc[df['purvuosi_loppu'].isnull(), 'purvuosi_loppu'] = loppu_default
        master_df = master_df.append(df)

    else:
        master_df = df
    master_df.reset_index(drop=True, inplace=True)

master_df = master_df.to_crs({'init': 'epsg:4326'})
master_df.to_file(driver='ESRI Shapefile', filename=os.path.join(geoserver_folder, "all_merged.shp"))

master_df.to_file(driver='ESRI Shapefile', filename=os.path.join(data_folder, "all_merged.shp"))




