"use strict";
if $("body").width() < 1400 and $("body").height() < 1000
    startzoom = 15 #13.5
else
    startzoom = 15 #13.5
bounds = new L.LatLngBounds [60.114,24.750], [60.32, 25.300]

vector_layers = L.layerGroup()

sp_layer = L.tileLayer.wms('http://localhost:8082/geoserver/ows?',
  layers: 'hfors:geotiff_coverage_2'
)

map = L.map 'map',
    minZoom: 11
    maxBounds: bounds
    zoomControl: false
    zoomSnap: 0
    zoomDelta: 0.01
    layers: [vector_layers, sp_layer]


map.addControl(new L.Control.Zoom({"position":"topright"}))
map.setView([60.171944, 24.941389], startzoom)
map.doubleClickZoom.disable()
#map.zoomSnap = 0
#map.zoomDelta = 0.01


# This function imports the buildings
get_wfs = (type, args, callback) ->
    url = GEOSERVER_BASE_URL + 'wfs/'
    params =
        service: 'WFS'
        version: '1.1.0'
        request: 'GetFeature'
        typeName: type
        srsName: 'EPSG:4326'
        outputFormat: 'application/json'
    for key of args
        params[key] = args[key]
    $.getJSON url, params, callback

marker = null
input_addr_map = null

myIcon = L.icon(
    iconUrl: 'images/flat.svg',
    iconSize: [25, 39]
    iconAnchor: [12, 39]
)

# returns queries for addresses
$("#address-input").typeahead(
    source: (query, process_cb) ->
        url_query = encodeURIComponent(query)
        $.getJSON(GEOCODER_URL + 'v1/address/?format=json&name=' + url_query, (data) ->
            objs = data.objects
            ret = []
            input_addr_map = []
            for obj in objs
                if obj.name.indexOf(", Espoo") > -1
                    continue
                if obj.name.indexOf(", Vantaa") > -1
                    continue   
                ret.push(obj.name)
            input_addr_map = objs
            process_cb(ret)
        )
)

$("#address-input").on 'change', ->
    match_obj = null
    for obj in input_addr_map
        if obj.name == $(this).val()
            match_obj = obj
            break
    if not match_obj
        if marker
            marker.setLatLng([0,0])
        return
    coords = obj.location.coordinates
    if not marker
        marker = L.marker([coords[1], coords[0]],
            draggable: false
            keyboard: false
            icon: myIcon
        )
        marker.addTo(map)
    else
        marker.setLatLng([coords[1], coords[0]])
    map.setView([coords[1], coords[0]], 16)

input_district_map = null
active_district = null

$("#district-input").typeahead(
    source: (query, process_cb) ->
        $.getJSON(GEOCODER_URL + 'v1/district/', {input: query}, (data) ->
            objs = data.objects
            ret = []
            input_addr_map = []
            for obj in objs
                ret.push(obj.name)
            input_district_map = objs
            process_cb(ret)
        )
)

$("#district-input").on 'change', ->
    match_obj = null
    if not $(this).val().length
        if active_district
            map.removeLayer active_district
            active_district = null
        return

    for obj in input_district_map
        if obj.name == $(this).val()
            match_obj = obj
            break
    if not match_obj
        return

    if active_district
        map.removeLayer active_district
    borders = L.geoJson match_obj.borders,
        style:
            weight: 2
            fillOpacity: 0.08
            color: "FF0000"
    borders.bindPopup match_obj.name
    borders.addTo map
    map.fitBounds borders.getBounds()
    active_district = borders

# Display if already checked
if $("#toggle_building_color:checked")
  use_colors = true

# Toggle on change
$("#toggle_building_color").change ->
  if use_colors
    use_colors = false
  else
    use_colors = true
  redraw_layers()

  # Display if already checked
if $("#toggle_vector_layers:checked")
  vector_layers_active = true
  #refresh_buildings()

# Toggle on change
$("#toggle_vector_layers").change ->
  if vector_layers_active
    vector_layers_active = false
    purge_vector_layer()
  else
    vector_layers_active = true
    refresh_buildings()
    vector_layers.addTo(map)

slider_max = 2030
slider_min = 1800

current_state = {}

redraw_layers = ->
    if not building_layer
        return
    building_layer.setStyle building_styler
    building_layer.setZIndex(50)
    if not transport_layer
        return
    transport_layer.setStyle transport_styler
    transport_layer.setZIndex(55)
    if not water_layer
        return
    water_layer.setStyle water_styler
    water_layer.setZIndex(99)
    if not land_layer
        return
    land_layer.setStyle land_styler

update_screen = (val, force_refresh) ->
  if current_state.year_built_first != val
      current_state.year_built_first = val
      redraw_layers()
      $("#mainhead").html(window.BAGE_TEXT.mainhead+val);


slider = $("#slider").slider
    min: slider_min
    max: slider_max
    value: slider_max
    tooltip: 'hide'
    handle: 'triangle'

animating = false
int = null

slider.on 'slide', (ev) ->
    if animating
        clearInterval int
        $("#play-btn").html '<span class="glyphicon glyphicon-play"></span>'
        animating = false
    update_screen ev.value

select_year = (val) ->
    slider.slider 'setValue', val
    update_screen val

update_screen slider_max

#colors = ['#FFFFD9', '#EDF8B1', '#C7E9B4', '#7FCDBB', '#41B6C4', '#1D91C0', '#225EA8', '#253494', '#081D58' ]
#colors = ['#FF8D00', '#F77B04', '#EF6908', '#E7580C', '#DF4610', '#D73414', '#CF2318', '#C7111C', '#BF0021' ]
#colors = ['#F9B7C7', '#FAACB5', '#FAA0A2', '#FB9C94', '#FB9D88', '#FBA17C', '#FCA770', '#FCAF64', '#FDBB58' ]
colors = ['#0003E5', '#005FE1', '#00B7DD', '#00D9A6', '#00D54C', '#0AD200', '#5DCE00', '#AECA00', '#C69100', '#C23F00', '#BF000E' ]
#colors = ['#a50026','#d73027','#f46d43','#fdae61','#fee090','#ffffbf','#e0f3f8','#abd9e9','#74add1','#4575b4','#313695']

building_styler = (feat) ->
    ret =
        weight: 0.5
        opacity: 1
        fillOpacity: 1
        color: '#242424'
    year_built_first = parseInt feat.properties.rakvuosi_a
    year_built_last = parseInt feat.properties.rakvuosi_l
    year_removed_first = parseInt feat.properties.purvuosi_a
    year_removed_last = parseInt feat.properties.purvuosi_l
    opacity_built = (current_state.year_built_first-year_built_first)/(year_built_last-year_built_first)
    opacity_demolished =  1 - (current_state.year_built_first-year_removed_first)/(year_removed_last-year_removed_first)
    if current_state.year_built_first and year_built_first >= current_state.year_built_first
        ret.opacity = 0
        ret.fillOpacity = 0
    if current_state.year_built_first and year_removed_last <= current_state.year_built_first
        ret.opacity = 0
        ret.fillOpacity = 0

    if opacity_built >= 0 and opacity_built <= 1
        ret.opacity = opacity_built
        ret.fillOpacity = opacity_built
    if opacity_demolished >= 0 and opacity_demolished <= 1
        ret.opacity = opacity_demolished
        ret.fillOpacity = opacity_demolished

    if use_colors
        if not year_built_first or year_built_first == 9999
            color = '#eee'
        else
            start_year = slider_min
            end_year = slider_max
            #year += (end_year-1 - current_state.year)
            n = Math.floor (year_built_first - start_year) * colors.length / (end_year - start_year)
            n = colors.length - n - 1
            color = colors[n]
            if not color
                color = colors[colors.length-1]
    else
        color = '#5A5A5A'
    #ret.color = '#FFFFFF'
    #ret.opacity = 0
    ret.color = color
    ret.fillColor = color
    return ret

water_styler = (feat) ->
    ret =
        weight: 1
        opacity: 1
        fillOpacity: 1
    year_built_first = parseInt feat.properties.vesi_alku || 0
    year_built_last = parseInt feat.properties.vesi_loppu || 0
    year_removed_first = parseInt feat.properties.maa_alku || 9999
    year_removed_last = parseInt feat.properties.maa_loppu || 9999
    opacity_built = (current_state.year_built_first-year_built_first)/(year_built_last-year_built_first)
    opacity_demolished =  1 - (current_state.year_built_first-year_removed_first)/(year_removed_last-year_removed_first)
    if current_state.year_built_first and year_built_first >= current_state.year_built_first
        ret.opacity = 0
        ret.fillOpacity = 0
    if current_state.year_built_first and year_removed_last <= current_state.year_built_first
        ret.opacity = 0
        ret.fillOpacity = 0

    if opacity_built >= 0 and opacity_built <= 1
        ret.opacity = opacity_built
        ret.fillOpacity = opacity_built
    if opacity_demolished >= 0 and opacity_demolished <= 1
        ret.opacity = opacity_demolished
        ret.fillOpacity = opacity_demolished
    if not year_built_first or year_built_first == 9999
        color = '#eee'
    else
        start_year = slider_min
        end_year = slider_max
        #year += (end_year-1 - current_state.year)
        n = Math.floor (year_built_first - start_year) * colors.length / (end_year - start_year)
        n = colors.length - n - 1
        color = '#eee'
    ret.color = '#bce4e4'
    ret.fillColor = '#bce4e4'   #5db2bb #a8c9ff #bce4e4
    return ret

transport_styler = (feat) ->
    ret =
        weight: 1
        opacity: 1
        fillOpacity: 1
    year_built_first = parseInt feat.properties.rak_alku || 0
    year_built_last = parseInt feat.properties.rak_loppu || 0
    year_removed_first = parseInt feat.properties.pur_alku || 9999
    year_removed_last = parseInt feat.properties.pur_loppu || 9999
    opacity_built = (current_state.year_built_first-year_built_first)/(year_built_last-year_built_first)
    opacity_demolished =  1 - (current_state.year_built_first-year_removed_first)/(year_removed_last-year_removed_first)
    if current_state.year_built_first and year_built_first >= current_state.year_built_first
        ret.opacity = 0
        ret.fillOpacity = 0
    if current_state.year_built_first and year_removed_last <= current_state.year_built_first
        ret.opacity = 0
        ret.fillOpacity = 0

    if opacity_built >= 0 and opacity_built <= 1
        ret.opacity = opacity_built
        ret.fillOpacity = opacity_built
    if opacity_demolished >= 0 and opacity_demolished <= 1
        ret.opacity = opacity_demolished
        ret.fillOpacity = opacity_demolished
    if not year_built_first or year_built_first == 9999
        color = '#eee'
    else
        start_year = slider_min
        end_year = slider_max
        #year += (end_year-1 - current_state.year)
        n = Math.floor (year_built_first - start_year) * colors.length / (end_year - start_year)
        n = colors.length - n - 1
        color = '#eee'
    ret.color = '#5A5A5A'
    ret.fillColor = '#bce4e4'   #5db2bb #a8c9ff #bce4e4
    return ret

land_styler = (feat) ->
    ret =
        weight: 0.5
        opacity: 0.5
        fillOpacity: 0.5
    tyyppi = feat.properties.tyyppi
    comment = """
    year_built_first = parseInt feat.properties.vesi_alku || 0
    year_built_last = parseInt feat.properties.vesi_loppu || 0
    year_removed_first = parseInt feat.properties.maa_alku || 9999
    year_removed_last = parseInt feat.properties.maa_loppu || 9999
    opacity_built = (current_state.year_built_first-year_built_first)/(year_built_last-year_built_first)
    opacity_demolished =  1 - (current_state.year_built_first-year_removed_first)/(year_removed_last-year_removed_first)
    if current_state.year_built_first and year_built_first >= current_state.year_built_first
        ret.opacity = 0
        ret.fillOpacity = 0
    if current_state.year_built_first and year_removed_last <= current_state.year_built_first
        ret.opacity = 0
        ret.fillOpacity = 0

    if opacity_built >= 0 and opacity_built <= 1
        ret.opacity = opacity_built
        ret.fillOpacity = opacity_built
    if opacity_demolished >= 0 and opacity_demolished <= 1
        ret.opacity = opacity_demolished
        ret.fillOpacity = opacity_demolished
    if not year_built_first or year_built_first == 9999
        color = '#eee'
    else
        start_year = slider_min
        end_year = slider_max
        #year += (end_year-1 - current_state.year)
        n = Math.floor (year_built_first - start_year) * colors.length / (end_year - start_year)
        n = colors.length - n - 1
        color = '#eee'
    """
    ret.color = '#bce4e4'
    ret.fillColor = '#bce4e4'
    ret.fillOpacity = 0
    if tyyppi == 'pelto'
        ret.color = '#fff3d4'
        ret.fillColor = '#FAFAEC'   #5db2bb #a8c9ff #bce4e4
        ret.fillOpacity = 0
    if tyyppi == 'metsä'
        ret.color = '#d2e1ab'
        ret.fillColor = '#F1F8DD'
        ret.fillOpacity = 0


    return ret

building_layer = null
transport_layer = null
water_layer = null
land_layer = null


display_building_modal = (address, year_built_first, latlng, search_string) ->
    $(".modal").remove()
            # returns queries for finna images

    modal = $("""
    <div class="modal hide fade" tabindex="-1" role="dialog" aria-hidden="true">
        <div class="modal-header">
            <button type="button" class="close" data-dismiss="modal" aria-hidden="true">×</button>
            <h3>#{address} (#{year_built_first})</h3>
        </div>

        <div class="modal-body" id="finna_images">

        <div class="modal-footer">
            <button class="btn" data-dismiss="modal" aria-hidden="true">#{window.BAGE_TEXT.close}</button>
        </div>
    </div>
    """)

    modal.on 'shown', ->
        streetView address, latlng


    url_query = encodeURIComponent(address)
    if address.length > 0
        get_finna(search_string, 10)

    '''
        $.ajax
          url: "https://api.finna.fi/api/v1/search?lookfor=\""+address + "\" AND \"Helsinki\"" + '&type=AllFields&field[]=images'
          dataType: "json"
          error: (jqXHR, textStatus, errorThrown) ->
              $('body').append '<hl>' + "AJAX Error: #{textStatus}"  + '</hl>'
          success: (data, textStatus, jqXHR) ->
              $('body').append '<hl>' + "Successful AJAX call: #{data}"  + '</hl>'
              img_urls = ("https://finna.fi" + x.images[0] for x in data.records)
              max_imgs = 10
              img_html = ""
              for img_url,i in img_urls.slice(0,max_imgs)
                img_html = img_html + "<img src=#{img_url}>"
              $("#finna_images").html '<div>' + img_html + '</div>' #JSON.stringify(data)


    '''
    $("body").append modal
    modal.modal('show')

get_finna = (search_terms, max_imgs, hash_code="#finna_images", aika_alku='0', aika_loppu='9999') ->
    search_string = ""
    for search_term in search_terms
        search_term = "\"" + search_term + "\""
        if search_string
            search_string = search_string.concat " OR "
        search_string = search_string.concat search_term
    get_finna2(search_string, max_imgs, hash_code, aika_alku, aika_loppu)

get_finna2 = (address, max_imgs, hash_code="#finna_images", aika_alku='0', aika_loppu='9999') ->
    $.ajax
        url: "https://api.finna.fi/api/v1/search?lookfor="+address + " AND \"Helsinki\"" +
        '&type=AllFields&field[]=images&filter[]=search_daterange_mv:[' + aika_alku + ' TO ' + aika_loppu + ']'
        dataType: "json"

        error: (jqXHR, textStatus, errorThrown) ->
          $('body').append '<hl>' + "AJAX Error: #{textStatus}"  + '</hl>'
        success: (data, textStatus, jqXHR) ->
          $('body').append '<hl>' + "Successful AJAX call: #{data}"  + '</hl>'
          img_urls = ("https://finna.fi" + x.images[0] for x in data.records)
          img_html = ""
          #style_h = "height: " + str(height)+"px"
          for img_url,i in img_urls.slice(0,max_imgs)
            img_html = img_html + "<img src=#{img_url} style='height: 100px'>"
          return $(hash_code).html '<div>' + img_html + '</div>'

purge_vector_layer = ->
  if vector_layers
    map.removeLayer vector_layers
    vector_layers = L.layerGroup()
  if building_layer
      map.removeLayer building_layer
      building_layer = null
  if transport_layer
      map.removeLayer transport_layer
      transport_layer = null
  if water_layer
      map.removeLayer water_layer
      water_layer = null
  if land_layer
      map.removeLayer land_layer
      land_layer = null

refresh_buildings = ->
    if map.getZoom() < 11
        purge_vector_layer()
        $("#zoominfo").show(); 
        return
    $("#zoominfo").hide();
    str = map.getBounds().toBBoxString() + ',EPSG:4326'

    get_wfs 'hfors:all_merged',
        maxFeatures: 50000
        bbox: str
        propertyName: 'rakvuosi_a,rakvuosi_l,purvuosi_a,purvuosi_l,suunnittel,Nimi,Osoite,the_geom,kuvat'
        , (data) ->
            if building_layer
                map.removeLayer building_layer
            building_layer = L.geoJson data,
                style: building_styler
                onEachFeature: (feat, layer) ->
                    year_built_first = feat.properties.rakvuosi_a
                    year_built_last = feat.properties.rakvuosi_l
                    year_removed_first = feat.properties.purvuosi_a
                    year_removed_last = feat.properties.purvuosi_l
                    planner = feat.properties.suunnittel
                    building_name = feat.properties.Nimi
                    kuvat = feat.properties.kuvat.split(",")
                    #if kuvat[0] == "" then "images/info.png" else "https://finna.fi/Cover/Show?id=hkm.HKMS000005:"+kuvat[0]
                     #
                    # creating string to display year(s) of construction and demolision
                    if year_built_first == year_built_last
                        built_threshold = year_built_first
                    else
                        built_threshold = year_built_first.toString().concat(" - ", year_built_last.toString())
                    if year_removed_first == year_removed_last
                        removed_threshold = year_removed_first
                    else
                        removed_threshold = year_removed_first.toString().concat(" - ", year_removed_last.toString())

                    address = feat.properties.Osoite

                    if address
                        address = address.replace /(\d){5} [A-Z]+/, ""
                    search_terms = [building_name, address]
                    if not building_name
                        display_name = address
                    else
                        display_name = building_name

                    layer.bindPopup """#{window.BAGE_TEXT.building_name} #{display_name}\n
                    <BR/> #{window.BAGE_TEXT.built} #{built_threshold}\n
                    <BR/> #{window.BAGE_TEXT.demolished} #{removed_threshold}
                    <BR/> #{window.BAGE_TEXT.planner} #{planner}


                    <BR/> <div class="popup-body" id="finna_images2" style="height: 100px">""",
                        closeOnClick: false
                        closeButton: false
                        autoPan: false
                        offset: new L.Point(100, -100)
                    if building_styler(feat).fillOpacity > 0
                        layer.on "mouseover", (e) ->

                            layer.setStyle
                                weight: 2,
                                color: '#f0f'
                            if(!L.Browser.ie && !L.Browser.opera)
                                layer.bringToFront();
                            get_finna(search_terms, 1, "#finna_images2", year_built_first, year_removed_last)
                            layer.openPopup()
                            return
                        layer.on "mouseout", (e) ->
                            building_layer.resetStyle(layer)
                            map.closePopup()
                            return
                        layer.on "click", (e) ->
                            display_building_modal display_name, year_built_first, e.latlng, search_terms
            building_layer.addTo vector_layers
            building_layer.zIndex = 50

    get_wfs 'hfors:trafik',
        maxFeatures: 10000
        bbox: str
        propertyName: 'rak_alku,rak_loppu,pur_alku,pur_loppu,the_geom'
        , (data) ->
            if transport_layer
                map.removeLayer transport_layer
            transport_layer = L.geoJson data,
                style: transport_styler
                onEachFeature: (feat, layer) ->
                    year_built_first = feat.properties.rak_alku
                    year_built_last = feat.properties.rak_loppu
                    year_removed_first = feat.properties.pur_alku
                    year_removed_last = feat.properties.pur_loppu
                 #layer.setZIndex(99)
            transport_layer.zIndex = 55
            transport_layer.addTo vector_layers

    get_wfs 'hfors:all_water',
        maxFeatures: 10000
        bbox: str
        propertyName: 'vesi_alku,vesi_loppu,maa_alku,maa_loppu,the_geom'
        , (data) ->
            if water_layer
                map.removeLayer water_layer
            water_layer = L.geoJson data,
                style: water_styler
                onEachFeature: (feat, layer) ->
                    year_built_first = feat.properties.vesi_alku
                    year_built_last = feat.properties.vesi_loppu
                    year_removed_first = feat.properties.maa_alku
                    year_removed_last = feat.properties.maa_loppu
                 #layer.setZIndex(99)
            water_layer.zIndex = 90
            water_layer.addTo vector_layers

    get_wfs 'hfors:land',
        maxFeatures: 10000
        bbox: str
        propertyName: 'tyyppi,the_geom'
        , (data) ->
            if land_layer
                map.removeLayer land_layer
            land_layer = L.geoJson data,
                style: land_styler
                onEachFeature: (feat, layer) ->
                    tyyppi = feat.properties.tyyppi
                    #year_built_first = feat.properties.vesi_alku
                    #year_built_last = feat.properties.vesi_loppu
                    #year_removed_first = feat.properties.maa_alku
                    #year_removed_last = feat.properties.maa_loppu
            land_layer.zIndex = 90
            land_layer.addTo vector_layers

map.on 'moveend', refresh_buildings

$(".infobut").click ->
    $(".infodiv").slideToggle()


overlayMaps = "Smith Polvinen": sp_layer
baseMaps = "" #"City": vector_layers

L.control.layers(baseMaps, overlayMaps).addTo(map)

refresh_buildings()

$("#play-btn").click ->
    if animating
        clearInterval int
        $(this).html '<span class="glyphicon glyphicon-play"></span>'
    else
        $(this).html '<span class="glyphicon glyphicon-pause"></span>'
        if current_state.year_built_first is slider_max
            select_year slider_min
        int = setInterval () ->
                newyear = current_state.year_built_first + 1
                if newyear <= slider_max
                    select_year newyear
                else
                    clearInterval int
                    select_year slider_max
                    $("#play-btn").html "&#9658;"
                    animating = false
            , 500 # this is the delay between years
    animating =  not animating


