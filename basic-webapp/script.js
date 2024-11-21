document.addEventListener('DOMContentLoaded', () => {
    // Elementy interfejsu
    const tabButtons = document.querySelectorAll('.tab-button');
    const tabContents = document.querySelectorAll('.tab-content');
    const esp32IpInput = document.getElementById('esp32Ip');
    const brightnessSlider = document.getElementById('brightness');
    const brightnessValue = document.getElementById('brightnessValue');
    const ledSwitch = document.getElementById('ledSwitch');
    const presetsButtonsContainer = document.getElementById('presetsButtons');
    const addPresetBtn = document.getElementById('addPresetBtn');
    const pickColorBtn = document.getElementById('pickColorBtn');
    const currentColorDisplay = document.getElementById('currentColorDisplay');
    const segmentsGrid = document.getElementById('segmentsGrid');
    const applySegmentsBtn = document.getElementById('applySegmentsBtn');
    const presetModal = document.getElementById('presetModal');
    const presetNameInput = document.getElementById('presetName');
    const savePresetBtn = document.getElementById('savePresetBtn');
    const cancelPresetBtn = document.getElementById('cancelPresetBtn');
  
    let esp32Ip = '';
    let currentColor = '#ffffff';
    let brightness = 255;
    let isOn = true;
  
    const presets = [
      { name: 'Blade Runner', preset: 'blade_runner' },
      { name: 'Mruganie', preset: 'blink' },
      { name: 'Niebieski', preset: 'blue' },
      { name: 'Czerwony', preset: 'red' },
      { name: 'Zielony', preset: 'green' },
      { name: 'Biały', preset: 'white' },
    ];
  
    // Obsługa zakładek
    tabButtons.forEach(button => {
      button.addEventListener('click', () => {
        const tab = button.dataset.tab;
  
        // Dezaktywuj wszystkie zakładki i treści
        tabButtons.forEach(btn => btn.classList.remove('border-b-2', 'border-blue-600', 'text-blue-600'));
        tabContents.forEach(content => content.classList.add('hidden'));
  
        // Aktywuj wybraną zakładkę i treść
        button.classList.add('border-b-2', 'border-blue-600', 'text-blue-600');
        document.getElementById(tab).classList.remove('hidden');
      });
    });
  
    // Aktualizacja adresu IP
    esp32IpInput.addEventListener('change', () => {
      esp32Ip = esp32IpInput.value.trim();
    });
  
    // Aktualizacja jasności
    brightnessSlider.addEventListener('input', () => {
      brightness = brightnessSlider.value;
      brightnessValue.textContent = brightness;
      setBrightness();
    });
  
    // Przełącznik LED
    ledSwitch.addEventListener('change', () => {
      isOn = ledSwitch.checked;
      toggleLED();
    });
  
    // Generowanie przycisków presetów
    function generatePresets() {
      presetsButtonsContainer.innerHTML = '';
      presets.forEach(preset => {
        const button = document.createElement('button');
        button.className = 'px-4 py-2 bg-gray-200 rounded-md hover:bg-gray-300';
        button.textContent = preset.name;
        button.addEventListener('click', () => setPreset(preset.preset));
        presetsButtonsContainer.appendChild(button);
      });
    }
  
    generatePresets();
  
    // Dodawanie nowego presetu
    addPresetBtn.addEventListener('click', () => {
      presetModal.classList.remove('hidden');
    });
  
    cancelPresetBtn.addEventListener('click', () => {
      presetModal.classList.add('hidden');
      presetNameInput.value = '';
    });
  
    savePresetBtn.addEventListener('click', async () => {
      const presetName = presetNameInput.value.trim();
      if (!presetName) {
        alert('Proszę wpisać nazwę presetu.');
        return;
      }
      presetModal.classList.add('hidden');
      presetNameInput.value = '';
      const color = await pickColor();
      if (color) {
        currentColor = color;
        presets.push({ name: presetName, preset: `custom_${presets.length + 1}`, color: currentColor });
        generatePresets();
        await setColor(currentColor);
      }
    });
  
    // Wybór koloru
    pickColorBtn.addEventListener('click', async () => {
      const color = await pickColor();
      if (color) {
        currentColor = color;
        currentColorDisplay.style.backgroundColor = currentColor;
        await setColor(currentColor);
      }
    });
  
    // Funkcja wyboru koloru
    function pickColor() {
      return new Promise((resolve) => {
        const input = document.createElement('input');
        input.type = 'color';
        input.value = currentColor;
        input.style.position = 'absolute';
        input.style.left = '-9999px';
        document.body.appendChild(input);
        input.click();
        input.addEventListener('input', () => {
          resolve(input.value);
          document.body.removeChild(input);
        });
        input.addEventListener('blur', () => {
          resolve(null);
          document.body.removeChild(input);
        });
      });
    }
  
    // Generowanie segmentów
    const segmentColors = {};
    function generateSegments() {
      segmentsGrid.innerHTML = '';
      for (let i = 0; i < 12; i++) {
        const segment = document.createElement('div');
        segment.className = 'segment';
        segment.textContent = `S${i + 1}`;
        segment.style.backgroundColor = segmentColors[i] || 'grey';
        segment.addEventListener('click', async () => {
          const color = await pickColor();
          if (color) {
            segmentColors[i] = color;
            segment.style.backgroundColor = color;
          }
        });
        segmentsGrid.appendChild(segment);
      }
    }
  
    generateSegments();
  
    applySegmentsBtn.addEventListener('click', () => {
      applyCustomLeds();
    });
  
    // Funkcje komunikacji z ESP32
    async function sendRequest(endpoint, params = {}, method = 'GET', body = null) {
      if (!esp32Ip) {
        alert('Proszę wpisać adres IP ESP32.');
        return;
      }
      const url = `http://${esp32Ip}${endpoint}`;
      try {
        const options = {
          method,
          headers: {
            'Content-Type': 'application/json',
          },
        };
        if (body) {
          options.body = JSON.stringify(body);
        }
        const response = await fetch(url, options);
        if (!response.ok) {
          alert('Błąd podczas komunikacji z ESP32.');
        }
      } catch (error) {
        console.error('Błąd:', error);
        alert('Nie udało się połączyć z ESP32.');
      }
    }
  
    async function setColor(color) {
      const rgb = hexToRgb(color);
      await sendRequest('/setColor', {}, 'POST', { r: rgb.r, g: rgb.g, b: rgb.b });
    }
  
    async function setBrightness() {
      await sendRequest('/setBrightness', {}, 'POST', { brightness: parseInt(brightness) });
    }
  
    async function toggleLED() {
      const endpoint = isOn ? '/turnOn' : '/turnOff';
      await sendRequest(endpoint, {}, 'POST');
    }
  
    async function setPreset(preset) {
      await sendRequest('/setPreset', {}, 'POST', { preset });
    }
  
    async function applyCustomLeds() {
      const segmentsData = [];
      for (let i = 0; i < 12; i++) {
        if (segmentColors[i]) {
          const rgb = hexToRgb(segmentColors[i]);
          segmentsData.push({ segment: i, r: rgb.r, g: rgb.g, b: rgb.b });
        }
      }
      await sendRequest('/setCustomLeds', {}, 'POST', segmentsData);
    }
  
    function hexToRgb(hex) {
      const bigint = parseInt(hex.slice(1), 16);
      const r = (bigint >> 16) & 255;
      const g = (bigint >> 8) & 255;
      const b = bigint & 255;
      return { r, g, b };
    }
  });