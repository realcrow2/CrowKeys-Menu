let vehicles = [];
let selectedIndex = 0;
let isMenuOpen = false;
let isTrustedMenu = false;
let isTrustMenu = false;
let filteredVehicles = [];
let selectedVehicles = []; // For trust menu
let allSelected = false; // For trust menu "ALL" checkbox

// Listen for messages from Lua
window.addEventListener('message', function(event) {
    const data = event.data;
    
    if (data.action === 'showMenu') {
        vehicles = data.vehicles || [];
        filteredVehicles = vehicles;
        selectedIndex = 0;
        isTrustedMenu = false;
        isTrustMenu = false;
        document.getElementById('menu-title').textContent = 'Vehicle Keys';
        document.getElementById('menu-search').classList.add('hidden');
        document.getElementById('menu-player-input').classList.add('hidden');
        document.getElementById('menu-footer-buttons').classList.add('hidden');
        document.getElementById('footer-text').innerHTML = 'Use <kbd>↑</kbd> <kbd>↓</kbd> to navigate | <kbd>Enter</kbd> to select | <kbd>ESC</kbd> to close';
        showMenu();
    } else if (data.action === 'showTrustedMenu') {
        vehicles = data.vehicles || [];
        filteredVehicles = vehicles;
        selectedIndex = 0;
        isTrustedMenu = true;
        isTrustMenu = false;
        document.getElementById('menu-title').textContent = 'Trusted Players';
        document.getElementById('menu-search').classList.remove('hidden');
        document.getElementById('menu-player-input').classList.add('hidden');
        document.getElementById('menu-footer-buttons').classList.add('hidden');
        document.getElementById('footer-text').innerHTML = 'Use <kbd>ESC</kbd> to close';
        showMenu();
    } else if (data.action === 'showTrustMenu') {
        vehicles = data.vehicles || [];
        filteredVehicles = vehicles;
        selectedIndex = 0;
        isTrustedMenu = false;
        isTrustMenu = true;
        selectedVehicles = [];
        allSelected = false;
        document.getElementById('menu-title').textContent = 'Trust Vehicles';
        document.getElementById('menu-search').classList.add('hidden');
        document.getElementById('menu-player-input').classList.remove('hidden');
        document.getElementById('menu-footer-buttons').classList.remove('hidden');
        document.getElementById('player-id-input').value = '';
        document.getElementById('footer-text').innerHTML = 'Select vehicles and enter Player ID | <kbd>ESC</kbd> to close';
        showMenu();
    } else if (data.action === 'hideMenu') {
        hideMenu();
    }
});

// Search functionality
document.addEventListener('DOMContentLoaded', function() {
    const searchInput = document.getElementById('search-input');
    if (searchInput) {
        searchInput.addEventListener('input', function(e) {
            if (!isTrustedMenu) return;
            
            const searchTerm = e.target.value.trim();
            
            if (searchTerm === '') {
                filteredVehicles = vehicles;
            } else {
                const searchTermLower = searchTerm.toLowerCase();
                filteredVehicles = vehicles.filter(vehicle => {
                    // Check vehicle spawncode (case-insensitive)
                    if (vehicle.spawncode.toLowerCase().includes(searchTermLower)) {
                        return true;
                    }
                    
                    // Check trusted players (case-insensitive for names, exact match for Discord ID to allow number search)
                    if (vehicle.trustedPlayers) {
                        for (const player of vehicle.trustedPlayers) {
                            if (player.name.toLowerCase().includes(searchTermLower) || 
                                player.discordId.includes(searchTerm)) {
                                return true;
                            }
                        }
                    }
                    
                    return false;
                });
            }
            
            renderVehicles();
        });
    }
});

// Keyboard navigation
document.addEventListener('keydown', function(event) {
    if (!isMenuOpen) return;
    
    switch(event.key) {
        case 'ArrowUp':
            if (!isTrustedMenu) {
                event.preventDefault();
                navigateUp();
            }
            break;
        case 'ArrowDown':
            if (!isTrustedMenu) {
                event.preventDefault();
                navigateDown();
            }
            break;
        case 'Enter':
            if (!isTrustedMenu) {
                event.preventDefault();
                selectVehicle();
            }
            break;
        case 'Escape':
            event.preventDefault();
            closeMenu();
            break;
    }
});

function showMenu() {
    const container = document.getElementById('menu-container');
    container.classList.remove('hidden');
    isMenuOpen = true;
    
    if (isTrustedMenu) {
        const searchInput = document.getElementById('search-input');
        if (searchInput) {
            searchInput.value = '';
        }
    }
    
    if (isTrustMenu) {
        selectedVehicles = [];
        allSelected = false;
    }
    
    renderVehicles();
}

function hideMenu() {
    const container = document.getElementById('menu-container');
    container.classList.add('hidden');
    isMenuOpen = false;
}

function closeMenu() {
    hideMenu();
    if (isTrustMenu) {
        // Trust menu uses confirmTrust callback to close, or use closeMenu
        fetch(`https://crowkeys/closeMenu`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json; charset=UTF-8'
            },
            body: JSON.stringify({})
        }).then(response => response.json()).then(data => {
            // Menu closed
        }).catch(error => {
            console.error("Error closing menu:", error);
        });
    } else {
        const callback = isTrustedMenu ? 'closeTrustedMenu' : 'closeMenu';
        fetch(`https://crowkeys/${callback}`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json; charset=UTF-8'
            },
            body: JSON.stringify({})
        }).then(response => response.json()).then(data => {
            // Menu closed
        }).catch(error => {
            console.error("Error closing menu:", error);
        });
    }
}

function renderVehicles() {
    const vehiclesList = document.getElementById('vehicles-list');
    const noVehicles = document.getElementById('no-vehicles');
    vehiclesList.innerHTML = '';
    
    const vehiclesToRender = isTrustedMenu ? filteredVehicles : vehicles;
    
    if (vehiclesToRender.length === 0) {
        noVehicles.classList.remove('hidden');
        if (isTrustedMenu) {
            noVehicles.querySelector('p').textContent = 'You don\'t have any trusted players';
        } else {
            noVehicles.querySelector('p').textContent = 'You don\'t have access to any vehicles';
        }
    } else {
        noVehicles.classList.add('hidden');
    }
    
    if (isTrustedMenu) {
        renderTrustedVehicles(vehiclesToRender, vehiclesList);
    } else if (isTrustMenu) {
        renderTrustVehicles(vehiclesToRender, vehiclesList);
    } else {
        renderKeysVehicles(vehiclesToRender, vehiclesList);
    }
}

function renderKeysVehicles(vehiclesToRender, vehiclesList) {
    vehiclesToRender.forEach((vehicle, index) => {
        const item = document.createElement('div');
        item.className = 'vehicle-item';
        item.dataset.index = index;
        
        const isOwned = vehicle.isOwner;
        
        item.innerHTML = `
            <div class="vehicle-info">
                <div class="vehicle-name">
                    ${vehicle.spawncode.toUpperCase()}
                    <span class="vehicle-badge ${isOwned ? 'owned' : 'trusted'}">
                        ${isOwned ? 'Owned' : 'Trusted'}
                    </span>
                </div>
                <div class="vehicle-description">
                    ${isOwned ? 'Your personal vehicle' : 'Vehicle trusted to you by another player'}
                </div>
            </div>
            <div class="vehicle-icon">🚗</div>
        `;
        
        // Add click handler for mouse clicks
        item.addEventListener('click', function() {
            selectedIndex = index;
            updateSelection();
            selectVehicle();
        });
        
        vehiclesList.appendChild(item);
    });
    updateSelection();
}

function renderTrustedVehicles(vehiclesToRender, vehiclesList) {
    vehiclesToRender.forEach((vehicle) => {
        const item = document.createElement('div');
        item.className = 'vehicle-item trusted-vehicle-item';
        
        item.innerHTML = `
            <div class="vehicle-header">
                <div class="vehicle-name">${vehicle.spawncode.toUpperCase()}</div>
            </div>
            <div class="trusted-list">
                ${vehicle.trustedPlayers.map(player => `
                    <div class="trusted-player">
                        <div class="player-info">
                            <div>
                                <div class="player-name">${player.name}</div>
                                <div class="player-discord">${player.discordId}</div>
                            </div>
                        </div>
                        <button class="remove-btn" data-spawncode="${vehicle.spawncode}" data-discordid="${player.discordId}">
                            Remove
                        </button>
                    </div>
                `).join('')}
            </div>
        `;
        
        vehiclesList.appendChild(item);
    });
    
    // Add event listeners to remove buttons
    document.querySelectorAll('.remove-btn').forEach(btn => {
        btn.addEventListener('click', function(e) {
            e.stopPropagation();
            const spawncode = this.dataset.spawncode;
            const discordId = this.dataset.discordid;
            
            removeTrust(spawncode, discordId, this);
        });
    });
}

function removeTrust(spawncode, discordId, button) {
    // First click - show confirm button
    if (!button.classList.contains('confirming')) {
        button.classList.add('confirming');
        button.textContent = 'Are you sure?';
        button.style.background = 'rgba(233, 69, 96, 0.5)';
        
        // Reset after 3 seconds if not clicked again
        setTimeout(() => {
            if (button.classList.contains('confirming')) {
                button.classList.remove('confirming');
                button.textContent = 'Remove';
                button.style.background = 'rgba(233, 69, 96, 0.2)';
            }
        }, 3000);
        return;
    }
    
    // Second click - actually remove
    button.classList.remove('confirming');
    button.textContent = 'Removing...';
    button.disabled = true;
    
    fetch(`https://crowkeys/removeTrust`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8'
        },
        body: JSON.stringify({
            spawncode: spawncode,
            discordId: discordId
        })
    });
}

function navigateUp() {
    if (selectedIndex > 0) {
        selectedIndex--;
    } else {
        selectedIndex = vehicles.length - 1;
    }
    updateSelection();
}

function navigateDown() {
    if (selectedIndex < vehicles.length - 1) {
        selectedIndex++;
    } else {
        selectedIndex = 0;
    }
    updateSelection();
}

function updateSelection() {
    const items = document.querySelectorAll('.vehicle-item');
    items.forEach((item, index) => {
        if (index === selectedIndex) {
            item.classList.add('selected');
            item.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
        } else {
            item.classList.remove('selected');
        }
    });
}

function selectVehicle() {
    if (vehicles[selectedIndex]) {
        const vehicle = vehicles[selectedIndex];
        hideMenu();
        
        fetch(`https://crowkeys/selectVehicle`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json; charset=UTF-8'
            },
            body: JSON.stringify({
                spawncode: vehicle.spawncode
            })
        });
    }
}

function renderTrustVehicles(vehiclesToRender, vehiclesList) {
    // Add "ALL" checkbox item
    const allItem = document.createElement('div');
    allItem.className = 'vehicle-item trust-vehicle-item';
    allItem.innerHTML = `
        <label class="vehicle-checkbox-label">
            <input type="checkbox" id="check-all" class="vehicle-checkbox" ${allSelected ? 'checked' : ''}>
            <span class="vehicle-name">ALL VEHICLES</span>
        </label>
    `;
    vehiclesList.appendChild(allItem);
    
    // Add event listener for "ALL" checkbox
    document.getElementById('check-all').addEventListener('change', function(e) {
        allSelected = e.target.checked;
        selectedVehicles = [];
        
        if (allSelected) {
            selectedVehicles = [...vehiclesToRender];
            // Check all vehicle checkboxes
            document.querySelectorAll('.vehicle-checkbox:not(#check-all)').forEach(cb => {
                cb.checked = true;
            });
        } else {
            // Uncheck all vehicle checkboxes
            document.querySelectorAll('.vehicle-checkbox:not(#check-all)').forEach(cb => {
                cb.checked = false;
            });
        }
    });
    
    // Add vehicle checkboxes
    vehiclesToRender.forEach((vehicle) => {
        const item = document.createElement('div');
        item.className = 'vehicle-item trust-vehicle-item';
        const spawncode = typeof vehicle === 'string' ? vehicle : vehicle.spawncode;
        const isChecked = selectedVehicles.includes(spawncode) || allSelected;
        
        item.innerHTML = `
            <label class="vehicle-checkbox-label">
                <input type="checkbox" class="vehicle-checkbox" data-spawncode="${spawncode}" ${isChecked ? 'checked' : ''}>
                <span class="vehicle-name">${spawncode.toUpperCase()}</span>
            </label>
        `;
        
        vehiclesList.appendChild(item);
        
        // Add event listener for vehicle checkbox
        const checkbox = item.querySelector('.vehicle-checkbox');
        checkbox.addEventListener('change', function(e) {
            const spawncode = this.dataset.spawncode;
            
            if (e.target.checked) {
                if (!selectedVehicles.includes(spawncode)) {
                    selectedVehicles.push(spawncode);
                }
            } else {
                selectedVehicles = selectedVehicles.filter(v => v !== spawncode);
                // Uncheck "ALL" if a vehicle is unchecked
                if (allSelected) {
                    allSelected = false;
                    document.getElementById('check-all').checked = false;
                }
            }
        });
    });
}

function confirmTrust() {
    const playerIdInput = document.getElementById('player-id-input');
    const playerId = playerIdInput.value.trim();
    
    // Get vehicles to trust - use selectedVehicles array which is maintained by checkbox changes
    let vehiclesToTrust = [];
    if (allSelected) {
        vehiclesToTrust = vehicles.map(v => typeof v === 'string' ? v : v.spawncode);
    } else {
        vehiclesToTrust = selectedVehicles;
    }
    
    // Send to server (server will validate and show errors via notifications)
    // Always close menu after sending - server handles validation
    fetch(`https://crowkeys/confirmTrust`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8'
        },
        body: JSON.stringify({
            targetPlayerId: playerId,
            selectedVehicles: vehiclesToTrust
        })
    }).then(response => response.json()).then(data => {
        // Close menu after successful send
        closeMenu();
    }).catch(error => {
        console.error("Error confirming trust:", error);
        // Always close menu even on error to prevent NUI focus lock
        closeMenu();
    });
}

// Close button click
document.getElementById('close-btn').addEventListener('click', closeMenu);

// Confirm button click
document.getElementById('confirm-btn').addEventListener('click', confirmTrust);
