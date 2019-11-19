"""
Structure:
file combining address, year and image urls

Scraping: goes trough every address (or other location identifyer search word) and searches for that on the website,
storing the relevant image urls to file

"""

from bs4 import BeautifulSoup
import requests
import pandas as pd
import time
import re

search_terms = ["mariankatu3"]
URL_BASE = 'https://www.helsinkikuvia.fi/search/?search='
col_names = [u'address', u'year', u'img_urls', u'img_urls', u'img_urls']
df = pd.DataFrame(columns=col_names)
for search_term in search_terms:

    url = []
    years = []
    page = requests.get(URL_BASE+str(search_term))
    #print page.content
    print(page)
    soup = BeautifulSoup(page.text.encode('utf-8', 'ignore'))
    img_elements = soup.findAll('img', attrs={'class': 'flex-img'})
    title_elements = soup.findAll('span', attrs={'class': "grid__meta--title"})
    other_elements = soup.findAll('span', attrs={'class': "grid__meta--other"})

    print(soup)
    for img_element, title_element, other_element in zip(img_elements, title_elements, other_elements):
        url.append(img_element["src"].split("https://finna.fi/Cover/Show?id=")[1].split("&")[0])
        nums = re.findall("(\d+)", other_element.text)
        year = []
        for num in nums:
            if len(num) == 4:
                year.append(num)
        years.append(year)
    print(years)
    print(url)
    time.sleep(0.1)

#df.to_csv(path_or_buf="D:\YIMBY\GISprojekt\Helsingfors byggnader genom tiderna\helsinkikuvia_scrape.csv", encoding='CP1252')
