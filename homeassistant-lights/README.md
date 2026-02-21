# Home Assistant Lights Plugin for Noctalia

Control your Home Assistant lights from your desktop bar.

## Features

- View all lights and their current state
- Toggle lights on/off with a single click
- Adjust brightness with sliders
- Quick actions to turn all lights on/off
- Middle-click on bar widget to toggle all lights
- Scroll wheel on bar widget to adjust selected light brightness
- Shows count of lights that are on in the bar

## Install

1. Copy this folder to `~/.config/noctalia/plugins/homeassistant-lights/`
2. Enable the plugin in Noctalia Settings > Plugins

## Setup

1. In Home Assistant, go to **Profile > Security > Long-Lived Access Tokens**
2. Create a new token and copy it
3. In Noctalia Settings > Plugins > Home Assistant Lights, enter:
   - Your Home Assistant URL (e.g., `http://homeassistant.local:8123`)
   - The access token you created
4. Optionally select a favorite light to control from the bar widget

## Usage

- **Left-click** on the bar widget to open the lights panel
- **Right-click** for quick actions (All On, All Off, Refresh)
- **Middle-click** to toggle all lights
- **Scroll wheel** to adjust brightness of the selected/favorite light

## Requirements

- Home Assistant instance accessible from your network
- Long-Lived Access Token from Home Assistant
- Light entities (entities starting with `light.`)

## Troubleshooting

- If the widget shows "disconnected", check your URL and token in settings
- Make sure your Home Assistant instance is accessible from your machine
- The URL should include the protocol (http:// or https://) and port if needed
