console.log('Hunting script.js loaded');

function GetParentResourceName() {
    console.log('GetParentResourceName called');
    return 'Dr-Hunting';
}

let currentIcons = {};

window.addEventListener('message', function(event) {
    const data = event.data;
    
    if (data.action === 'openUI') {
        openHuntingUI(data);
    } else if (data.action === 'closeUI') {
        document.getElementById('huntingUI').style.display = 'none';
    } else if (data.action === 'loadIcons') {
        loadAllIcons(data.icons);
    }
});

function loadAllIcons(icons) {
    currentIcons = icons;
    
    // console.log('Loading icons...', icons);
    
    if (icons.mainLogo && icons.mainLogo !== '') {
        const logoImg = document.getElementById('mainLogo');
        logoImg.src = icons.mainLogo;
        logoImg.onerror = function() {
            console.error('Failed to load main logo:', icons.mainLogo);
            this.style.display = 'none';
        };
        logoImg.onload = function() {
            // console.log('Main logo loaded successfully');
            this.style.display = 'block';
        };
    }
    
    if (icons.stats) {
        document.getElementById('icon-hunts').textContent = icons.stats.hunts || '🎯';
        document.getElementById('icon-animals').textContent = icons.stats.animals || '🦌';
        document.getElementById('icon-money').textContent = icons.stats.money || '💰';
        document.getElementById('icon-stored').textContent = icons.stats.stored || '📦';
        document.getElementById('icon-session').textContent = icons.stats.session || '🔫';
        document.getElementById('icon-viewList').textContent = icons.stats.viewList || '📋';
        document.getElementById('icon-stats-title').textContent = icons.stats.animals || '🦌';
    }
    
    if (icons.instructions) {
        document.getElementById('icon-step1').textContent = icons.instructions.step1 || '🚗';
        document.getElementById('icon-step2').textContent = icons.instructions.step2 || '🏹';
        document.getElementById('icon-step3').textContent = icons.instructions.step3 || '🛑';
        document.getElementById('icon-step4').textContent = icons.instructions.step4 || '📦';
    }
    
    if (icons.rewards) {
        document.getElementById('icon-reward-money').textContent = icons.rewards.money || '💵';
        document.getElementById('icon-reward-knife').textContent = icons.rewards.knife || '🔪';
    }
    
    if (icons.buttons) {
        document.getElementById('icon-btn-start').textContent = icons.buttons.start || '🏹';
        document.getElementById('icon-btn-end').textContent = icons.buttons.end || '🛑';
        document.getElementById('icon-btn-collect').textContent = icons.buttons.collect || '📦';
    }
    
    if (icons.header) {
        document.getElementById('icon-header').textContent = icons.header || '📖';
    }
    
    if (icons.footer) {
        document.getElementById('icon-footer').textContent = icons.footer || '🌲';
    }
    
    console.log('All icons loaded');
}

function openHuntingUI(data) {
    const ui = document.getElementById('huntingUI');
    ui.style.display = 'block';
    
    if (data.stats) {
        document.getElementById('totalHunts').textContent = data.stats.totalHunts || 0;
        document.getElementById('totalSkins').textContent = data.stats.totalSkins || 0;
        document.getElementById('totalEarned').textContent = '$' + (data.stats.totalEarned || 0).toLocaleString();
    }
    
    document.getElementById('currentSkins').textContent = (data.skinnedAnimals || 0);
    document.getElementById('collectedSkins').textContent = (data.collectedSkins || 0);
    
    const startBtn = document.getElementById('startBtn');
    const endBtn = document.getElementById('endBtn');
    const collectBtn = document.getElementById('collectBtn');
    
    if (data.isHunting) {
        startBtn.style.display = 'none';
        endBtn.style.display = 'flex';
        collectBtn.disabled = true;
    } else {
        startBtn.style.display = 'flex';
        endBtn.style.display = 'none';
        
        if (data.collectedSkins > 0 && !data.isDelivering) {
            collectBtn.disabled = false;
        } else {
            collectBtn.disabled = true;
        }
    }
    
    if (data.isDelivering) {
        startBtn.disabled = true;
        collectBtn.disabled = true;
    }
}

function showAnimals() {
    fetch(`https://${GetParentResourceName()}/getHuntedAnimals`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({})
    }).then(resp => resp.json()).then(data => {
        displayAnimals(data);
    });
}

function displayAnimals(data) {
    const modal = document.getElementById('animalsModal');
    const list = document.getElementById('animalsList');
    
    if (!data.animals || Object.keys(data.animals).length === 0) {
        list.innerHTML = `
            <div class="no-animals">
                <div class="no-animals-icon">🦌</div>
                <p style="font-size: 20px; font-weight: 900; color: #d4a574; margin-bottom: 15px; font-family: Arial;">NO ANIMALS HUNTED YET</p>
                <p style="font-size: 15px; opacity: 0.8; font-family: Arial;">Begin your hunting journey to build your collection</p>
            </div>
        `;
    } else {
        let html = '<div class="animals-grid">';
        
        for (const [animalType, count] of Object.entries(data.animals)) {
            const animalData = data.animalData[animalType] || {};
            const animalIcon = animalData.icon || 'https://via.placeholder.com/80?text=?';
            
            html += `
                <div class="animal-card">
                    <div class="animal-icon">
                        <img src="${animalIcon}" 
                             alt="${animalData.name || animalType}"
                             onerror="this.src='https://via.placeholder.com/80?text=Animal'">
                    </div>
                    <div class="animal-name">${animalData.name || animalType}</div>
                    <div class="animal-count">
                        Hunted
                        <span>${count}</span>
                    </div>
                </div>
            `;
        }
        
        html += '</div>';
        list.innerHTML = html;
    }
    
    modal.style.display = 'flex';
}

function closeAnimals() {
    document.getElementById('animalsModal').style.display = 'none';
}

function closeUI() {
    document.getElementById('huntingUI').style.display = 'none';
    document.getElementById('animalsModal').style.display = 'none';
    fetch(`https://${GetParentResourceName()}/closeUI`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({})
    });
}

function startHunt() {
    const ui = document.getElementById('huntingUI');
    ui.style.display = 'none';
    
    fetch(`https://${GetParentResourceName()}/startHunt`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({})
    });
}

function endMission() {
    const ui = document.getElementById('huntingUI');
    ui.style.display = 'none';
    
    fetch(`https://${GetParentResourceName()}/endMission`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({})
    });
}

function collectSkins() {
    const ui = document.getElementById('huntingUI');
    ui.style.display = 'none';
    
    fetch(`https://${GetParentResourceName()}/collectSkins`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({})
    });
}

document.addEventListener('keydown', function(event) {
    if (event.key === 'Escape') {
        closeUI();
    }
});