"use strict";
if $("body").width() < 1200 and $("body").height() < 1000
    startzoom = 15
else
    startzoom = 16
bounds = new L.LatLngBounds [60.114,24.750], [60.32, 25.300]
map = L.map 'map',
    minZoom: 11
    maxBounds: bounds
    zoomControl: false
map.addControl(new L.Control.Zoom({"position":"topright"}))
map.setView([60.171944, 24.941389], startzoom)
map.doubleClickZoom.disable()
#'http://{s}.tile.cloudmade.com/BC9A493B41014CAABB98F0471D759707/60640/256/{z}/{x}/{y}.png'
osm_roads_layer = L.tileLayer('http://a.tiles.mapbox.com/v3/aspirin.map-p0umewov/{z}/{x}/{y}.png',
    maxZoom: 18
    )

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

myIcon = L.icon(
    iconUrl: 'images/flat.svg',
    iconSize: [25, 39]
    iconAnchor: [12, 39]
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
            color: "#f0f"
    borders.bindPopup match_obj.name
    borders.addTo map
    map.fitBounds borders.getBounds()
    active_district = borders

slider_max = 2012
slider_min = 1812

current_state = {}

redraw_buildings = ->
    if not building_layer
        return
    building_layer.setStyle building_styler

update_screen = (val, force_refresh) ->  
    if current_state.year != val
        current_state.year = val
        redraw_buildings()
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

colors = ['#FFFFD9', '#EDF8B1', '#C7E9B4', '#7FCDBB', '#41B6C4', '#1D91C0', '#225EA8', '#253494', '#081D58' ]

building_styler = (feat) ->
    ret =
        weight: 1
        opacity: 1.0
        fillOpacity: 1.0
    year = parseInt feat.properties.valmvuosi
    if current_state.year and year > current_state.year
        ret.opacity = 0
        ret.fillOpacity = 0
    if not year or year == 9999
        color = '#eee'
    else
        start_year = slider_min
        end_year = slider_max
        year += (end_year-1 - current_state.year)
        n = Math.floor (year - start_year) * colors.length / (end_year - start_year)
        n = colors.length - n - 1
        color = colors[n]
        if not color
            color = colors[colors.length-1]
    ret.color = color
    return ret

building_layer = null

display_building_modal = (address, latlng) ->
    $(".modal").remove()
    modal = $("""
    <div class="modal hide fade" tabindex="-1" role="dialog" aria-hidden="true">
        <div class="modal-header">
            <button type="button" class="close" data-dismiss="modal" aria-hidden="true">×</button>
            <h3>#{address}</h3>
        </div>
        <div class="modal-body" id="street-canvas" style="height: 400px">

        </div>
        <div class="modal-footer">
            <button class="btn" data-dismiss="modal" aria-hidden="true">#{window.BAGE_TEXT.close}</button>
        </div>
    </div>
    """)
    
    modal.on 'shown', ->
        streetView address, latlng

    $("body").append modal
    modal.modal('show')
    


refresh_buildings = ->
    if map.getZoom() < 15
        if building_layer
            map.removeLayer building_layer
            building_layer = null
        $("#zoominfo").show(); 
        return
    $("#zoominfo").hide();
    str = map.getBounds().toBBoxString() + ',EPSG:4326'
    get_wfs 'hel:rakennukset',
        maxFeatures: 2500
        bbox: str
        propertyName: 'valmvuosi,osoite,wkb_geometry_s2'
        , (data) ->
            if building_layer
                map.removeLayer building_layer
            building_layer = L.geoJson data,
                style: building_styler
                onEachFeature: (feat, layer) ->
                    year = feat.properties.valmvuosi
                    address = feat.properties.osoite
                    if address
                        address = address.replace /(\d){5} [A-Z]+/, ""

                    layer.on "click", (e) ->
                        display_building_modal address, e.latlng
            building_layer.addTo map

map.on 'moveend', refresh_buildings

$(".infobut").click ->
    $(".infodiv").slideToggle()

map.addLayer osm_roads_layer
refresh_buildings()

$("#play-btn").click ->
    if animating
        clearInterval int
        $(this).html '<span class="glyphicon glyphicon-play"></span>'
    else
        $(this).html '<span class="glyphicon glyphicon-pause"></span>'
        if current_state.year is slider_max
            select_year slider_min
        int = setInterval () ->
                newyear = current_state.year + 1
                if newyear <= slider_max
                    select_year newyear
                else
                    clearInterval int
                    select_year slider_max
                    $("#play-btn").html "&#9658;"
                    animating = false
            , 50
    animating =  not animating

`function streetView(address, latlng){
    var point = new google.maps.LatLng(latlng.lat, latlng.lng),
        streetViewService = new google.maps.StreetViewService(),
        streetViewMaxDistance = 100;
    streetViewService.getPanoramaByLocation(point, streetViewMaxDistance, function(streetViewPanoramaData, status){

        if(status === google.maps.StreetViewStatus.OK){

            var oldPoint = point;
            point = streetViewPanoramaData.location.latLng;

            var heading = google.maps.geometry.spherical.computeHeading(point,oldPoint);            

            var panoramaOptions = {
                position: point,
                pov: {
                    heading: heading,
                    zoom: 1,
                    pitch: 0
                },
                panControl: false,
                enableCloseButton: false,
                linksControl: false,
                zoomControl: false,
                zoom: 1
            };
        var myPano = new google.maps.StreetViewPanorama(document.getElementById('street-canvas'), panoramaOptions);
        myPano.setVisible(true);

        }else{
          $("#street-canvas").html('<div style="line-height: 400px; text-align: center; font-size: 20px;-webkit-font-smoothing: antialiased;">' + window.BAGE_TEXT.streeterror + '</div>');
        }
    });
    
}`
