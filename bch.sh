import subprocess
import time
from datetime import datetime
import configparser
import os
import folium
import math
import json
import random
from tkinter import Tk
import qrcode

CONFIG_FILE = 'config.ini'
WALLET_PATH = ''
ELECTRON_CASH_PATH = ''
LATITUDE = 0.0
LONGITUDE = 0.0

def load_config():
    config = configparser.ConfigParser()
    config.read(CONFIG_FILE)
    global WALLET_PATH, ELECTRON_CASH_PATH, LATITUDE, LONGITUDE
    WALLET_PATH = config.get('Settings', 'WALLET_PATH')
    ELECTRON_CASH_PATH = config.get('Settings', 'ELECTRON_CASH_PATH')
    LATITUDE = float(config.get('Settings', 'LATITUDE'))
    LONGITUDE = float(config.get('Settings', 'LONGITUDE'))

def check_bch_balance():
    cmd = f"{ELECTRON_CASH_PATH} getbalance -w {WALLET_PATH}"
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    output = result.stdout.strip()
    if result.returncode == 0:
        try:
            balance_json = json.loads(output)
            confirmed_balance = float(balance_json.get("confirmed", 0))
            unconfirmed_balance = float(balance_json.get("unconfirmed", 0))
            total_balance = confirmed_balance + unconfirmed_balance
            return total_balance
        except (json.JSONDecodeError, ValueError):
            print("Error parsing balance response.")
            print("Response:", output)
    else:
        print("An error occurred while checking the balance.")
    return None

def calculate_fill_ratio(balance):
    max_balance = 0.001
    fill_ratio = min((balance / max_balance) * 100, 100) if max_balance != 0 else 0
    return fill_ratio

def generate_map(fill_ratio):
    # Współrzędne GPS z pliku config.ini
    GPS_coordinates = (LATITUDE, LONGITUDE)

    # Współrzędne losowego punktu wewnątrz koła
    max_radius_km = 1.0  # Maksymalny promień koła w kilometrach
    min_radius_km = 0.003  # Minimalny promień koła w kilometrach
    radius_km = (100 - fill_ratio) / 100 * (max_radius_km - min_radius_km) + min_radius_km
    random_radius = random.uniform(0, radius_km)
    random_angle = random.uniform(0, 2 * math.pi)
    random_latitude = LATITUDE + (random_radius / 111.32) * math.cos(random_angle)
    random_longitude = LONGITUDE + (random_radius / (111.32 * math.cos(math.radians(LATITUDE)))) * math.sin(random_angle)

    # Konwersja promienia z kilometrów na metry
    radius_m = radius_km * 1000

    # Tworzenie obiektu mapy
    map = folium.Map(location=GPS_coordinates, zoom_start=12)

    # Dodawanie warstwy satelitarnej OpenStreetMap
    folium.TileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', name='Satellite', attr='ESRI').add_to(map)

    # Dodawanie koła do mapy
    folium.Circle(
        location=(random_latitude, random_longitude),
        radius=radius_m,
        color='blue',
        fill=True,
        fill_color='blue'
    ).add_to(map)

    # Dodawanie kontrolki warstw
    folium.LayerControl().add_to(map)

    # Zapisywanie mapy do pliku HTML
    map.save('mapa.html')

def read_config():
    load_config()
    print(f"Wallet Path: {WALLET_PATH}")
    config = configparser.ConfigParser()
    config.read(CONFIG_FILE)
    adres_skrytki = config.get('Settings', 'ADRES_SKRYTKI')

    # Funkcja do kopiowania adresu do schowka
    def copy_to_clipboard(text):
        r = Tk()
        r.withdraw()
        r.clipboard_clear()
        r.clipboard_append(text)
        r.update()
        r.destroy()

    # Generowanie pliku HTML z podziałem na dwie połowy
    html_content = f'''
    <!DOCTYPE html>
    <html>
    <head>
        <title>Mapa z informacjami</title>
        <style>
            /* Ustawienie podziału strony na dwie połowy */
            body {{
                display: flex;
                flex-direction: row;
                height: 100vh;
                margin: 0;
                padding: 0;
            }}

            /* Styl dla lewej połowy (mapy) */
            #map-container {{
                width: 66.66%; /* 2/3 szerokości strony */
                height: 100%;
            }}

            /* Styl dla prawej połowy (informacje) */
            #info-container {{
                width: 33.33%; /* 1/3 szerokości strony */
                height: 100%;
                overflow-y: auto;
                background-color: #f5f5f5;
                padding: 20px;
            }}
        </style>
        <script>
            function copyAddressToClipboard() {{
                var address = document.getElementById("address").innerHTML;
                navigator.clipboard.writeText(address);
                alert("Address copied to clipboard!");
            }}
        </script>
    </head>
    <body>
        <div id="map-container">
            <!-- Tutaj umieść kod wygenerowanej mapy -->
            <iframe src="mapa.html" width="100%" height="100%" frameborder="0"></iframe>
        </div>
        <div id="info-container">
            <!-- Tutaj umieść swoje informacje, linki, grafiki, etc. -->
            <h1 style="text-align: center; font-size: 14px;">INFORMACJE I ZASADY:</h1>
            <p>
                1) bla bla bla bla bla <br>
                2) bla bla bla bla bla <br>
                3) bla bla bla bla bla <br>
                4) bla bla bla bla bla <br>
                5) bla bla bla bla bla <br>
                6) bla bla bla bla bla <br>
            </p>
            <a href="https://www.example.com">Przykładowy link1</a><br>
            <a href="https://www.example.com">Przykładowy link2</a><br>
            
            <div>
                
<div style="text-align: center;">
                <p><strong>Adres skrytki: <br><br></strong><span id="address">{adres_skrytki}</span><br>
                <button onclick="copyAddressToClipboard()">Kopiuj adres do schowka</button><br><br>
                <img src="qrcode.png" alt="QR Code" style="width: 200px; height: 200px;"><br></p> 
</div>

            </div>
        </div>
    </body>
    </html>
    '''

    # Generowanie kodu QR dla adresu skrytki
    qr = qrcode.QRCode(
        version=1,
        error_correction=qrcode.constants.ERROR_CORRECT_L,
        box_size=10,
        border=4,
    )
    qr.add_data(adres_skrytki)
    qr.make(fit=True)
    qr_img = qr.make_image(fill_color="black", back_color="white")
    qr_img.save("qrcode.png")

    # Zapisywanie zawartości pliku HTML
    with open('mapa_z_informacjami.html', 'w') as file:
        file.write(html_content)

while True:
    read_config()
    balance = check_bch_balance()
    if balance is not None:
        fill_ratio = calculate_fill_ratio(balance)
        current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{current_time}] Current BCH balance: {balance} BCH")
        print(f"[{current_time}] Fill Ratio: {fill_ratio}%")
        generate_map(fill_ratio)
    time.sleep(10)

