from bs4 import BeautifulSoup
import requests
import pandas as pd
import time

URL_BASE = 'http://www.korttelit.fi/rakennus.php/id/'
col_names = [u'raknimi', u'osoite', u'arkkitehti', u'rakennusvuosi', u'kaupunginosa', u'kortteli']
df = pd.DataFrame(columns=col_names)
for i in range(1500):

    row = []
    page = requests.get(URL_BASE+str(i))
    #print page.content

    soup = BeautifulSoup(page.text.encode('utf-8', 'ignore'))
    elements = soup.findAll('td', attrs={'class': 'value'})

    for element in elements:
        row.append(element.text.replace('\n', ''))

    if len(row) == 6:
        df.loc[i] = row
    time.sleep(0.1)
    printmes = '\r' + str(i)
    print printmes

df.to_csv(path_or_buf="D:\YIMBY\GISprojekt\Helsingfors byggnader genom tiderna\korttelit_scrape_nimi.csv", encoding='CP1252')
