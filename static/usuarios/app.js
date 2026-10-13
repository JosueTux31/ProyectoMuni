const API = {
    usuarios: "/api/usuarios/",
    roles: "/api/roles-usuarios/",
    autenticaciones: "/api/tipos-autenticacion/",
    identificaciones: "/api/tipos-identificacion/",
    departamentos: "/api/departamentos/",
    telefonos: "/api/tipos-telefonos/",
    correos: "/api/tipos-correos/",
    paises: "/api/paises/",
    provincias: "/api/provincias/",
    cantones: "/api/cantones/",
    distritos: "/api/distritos/"
};

const userForm = document.getElementById("userForm");
const userModal = document.getElementById("userModal");
const modalTitle = document.getElementById("modalTitle");

const usersTableBody = document.getElementById("usersTableBody");
const emptyUsers = document.getElementById("emptyUsers");
const loadingUsers = document.getElementById("loadingUsers");

const totalUsers = document.getElementById("totalUsers");
const activeUsers = document.getElementById("activeUsers");
const lastUpdate = document.getElementById("lastUpdate");

const searchInput = document.getElementById("searchInput");
const alertContainer = document.getElementById("alertContainer");

const phonesContainer = document.getElementById("phonesContainer");
const emailsContainer = document.getElementById("emailsContainer");
const websContainer = document.getElementById("websContainer");

let users = [];
let editingUser = null;
let phoneTypes = [];
let emailTypes = [];


/* ------------------------- Utilidades ------------------------- */

function getCookie(name) {
    const cookies = document.cookie.split(";");

    for (const cookie of cookies) {
        const item = cookie.trim();

        if (item.startsWith(`${name}=`)) {
            return decodeURIComponent(
                item.substring(name.length + 1)
            );
        }
    }

    return null;
}

function headers(json = false) {
    const result = {
        "Accept": "application/json"
    };

    const csrf = getCookie("csrftoken");

    if (csrf) {
        result["X-CSRFToken"] = csrf;
    }

    if (json) {
        result["Content-Type"] = "application/json";
    }

    return result;
}

function showAlert(message, type = "success") {
    alertContainer.innerHTML = "";

    const alert = document.createElement("div");
    alert.className = `alert alert-${type}`;
    alert.textContent = message;

    alertContainer.appendChild(alert);

    setTimeout(() => {
        alert.remove();
    }, 5000);
}

function extractResults(data) {
    if (Array.isArray(data)) {
        return data;
    }

    if (data && Array.isArray(data.results)) {
        return data.results;
    }

    return [];
}

function escapeHtml(value) {
    return String(value ?? "")
        .replaceAll("&", "&amp;")
        .replaceAll("<", "&lt;")
        .replaceAll(">", "&gt;")
        .replaceAll('"', "&quot;")
        .replaceAll("'", "&#039;");
}

async function request(url, options = {}) {
    const response = await fetch(url, {
        credentials: "same-origin",
        ...options
    });

    const text = await response.text();

    let data = null;

    try {
        data = text ? JSON.parse(text) : null;
    } catch {
        data = text;
    }

    if (!response.ok) {
        const message =
            data?.error ||
            data?.detail ||
            data?.mensaje ||
            `Error HTTP ${response.status}`;

        throw new Error(message);
    }

    return data;
}


/* ------------------------- Catálogos ------------------------- */

async function loadCatalog(endpoint, selectId, placeholder) {
    const select = document.getElementById(selectId);
    const data = await request(endpoint);
    const records = extractResults(data);

    select.innerHTML = "";

    const initialOption = document.createElement("option");
    initialOption.value = "";
    initialOption.textContent = placeholder;
    select.appendChild(initialOption);

    records.forEach((record) => {
        const option = document.createElement("option");

        option.value = getRecordId(record);
        option.textContent =
            record.descripcion ||
            record.nombre_pais ||
            record.nombre_provincia ||
            record.nombre_canton ||
            record.nombre_distrito;

        select.appendChild(option);
    });

    return records;
}

function getRecordId(record) {
    return (
        record.id ??
        record.cod_tipo_identificacion ??
        record.cod_rol ??
        record.cod_tipo_auth ??
        record.cod_departamento ??
        record.cod_telefono ??
        record.cod_correo ??
        record.cod_pais ??
        record.cod_provincia ??
        record.cod_canton ??
        record.cod_distrito
    );
}

async function loadInitialCatalogs() {
    try {
        phoneTypes = await loadCatalog(
            API.telefonos,
            "phoneType",
            "Tipo de teléfono"
        );

        emailTypes = await loadCatalog(
            API.correos,
            "emailType",
            "Tipo de correo"
        );

        await Promise.all([
            loadCatalog(API.roles, "codRol", "Seleccione un rol"),
            loadCatalog(
                API.autenticaciones,
                "codTipoAuth",
                "Seleccione autenticación"
            ),
            loadCatalog(
                API.identificaciones,
                "codTipoIdentificacion",
                "Seleccione identificación"
            ),
            loadCatalog(
                API.departamentos,
                "codDepartamento",
                "Sin departamento"
            ),
            loadCatalog(API.paises, "codPais", "Seleccione país")
        ]);
    } catch (error) {
        showAlert(
            `No se pudieron cargar los catálogos: ${error.message}`,
            "error"
        );
    }
}


/* ------------------------- Geografía ------------------------- */

async function loadProvinces() {
    const country = document.getElementById("codPais").value;
    const select = document.getElementById("codProvincia");

    resetSelect("codProvincia", "Seleccione provincia");
    resetSelect("codCanton", "Seleccione cantón");
    resetSelect("codDistrito", "Seleccione distrito");

    if (!country) {
        return;
    }

    select.disabled = false;

    const data = await request(
        `${API.provincias}?cod_pais=${encodeURIComponent(country)}`
    );

    const records = extractResults(data);

    fillSelect(
        select,
        records,
        "cod_provincia",
        "nombre_provincia",
        "Seleccione provincia"
    );
}

async function loadCantons() {
    const country = document.getElementById("codPais").value;
    const province = document.getElementById("codProvincia").value;
    const select = document.getElementById("codCanton");

    resetSelect("codCanton", "Seleccione cantón");
    resetSelect("codDistrito", "Seleccione distrito");

    if (!country || !province) {
        return;
    }

    select.disabled = false;

    const data = await request(
        `${API.cantones}?cod_pais=${encodeURIComponent(country)}&cod_provincia=${encodeURIComponent(province)}`
    );

    const records = extractResults(data);

    fillSelect(
        select,
        records,
        "cod_canton",
        "nombre_canton",
        "Seleccione cantón"
    );
}

async function loadDistricts() {
    const country = document.getElementById("codPais").value;
    const province = document.getElementById("codProvincia").value;
    const canton = document.getElementById("codCanton").value;
    const select = document.getElementById("codDistrito");

    resetSelect("codDistrito", "Seleccione distrito");

    if (!country || !province || !canton) {
        return;
    }

    select.disabled = false;

    const data = await request(
        `${API.distritos}?cod_pais=${encodeURIComponent(country)}&cod_provincia=${encodeURIComponent(province)}&cod_canton=${encodeURIComponent(canton)}`
    );

    const records = extractResults(data);

    fillSelect(
        select,
        records,
        "cod_distrito",
        "nombre_distrito",
        "Seleccione distrito"
    );
}

function fillSelect(
    select,
    records,
    valueField,
    labelField,
    placeholder
) {
    select.innerHTML = "";

    const initial = document.createElement("option");
    initial.value = "";
    initial.textContent = placeholder;
    select.appendChild(initial);

    records.forEach((record) => {
        const option = document.createElement("option");

        option.value = record[valueField];
        option.textContent = record[labelField];

        select.appendChild(option);
    });
}

function resetSelect(id, placeholder) {
    const select = document.getElementById(id);

    select.innerHTML = `
        <option value="">${placeholder}</option>
    `;

    select.disabled = true;
}


/* ------------------------- Usuarios ------------------------- */

async function loadUsers() {
    loadingUsers.classList.remove("hidden");

    try {
        const data = await request(API.usuarios);
        users = extractResults(data);

        renderUsers(users);
        updateStats();
    } catch (error) {
        showAlert(
            `No se pudieron cargar los usuarios: ${error.message}`,
            "error"
        );
    } finally {
        loadingUsers.classList.add("hidden");
    }
}

function renderUsers(records) {
    usersTableBody.innerHTML = "";

    if (!records.length) {
        emptyUsers.classList.remove("hidden");
        return;
    }

    emptyUsers.classList.add("hidden");

    records.forEach((user) => {
        const row = document.createElement("tr");

        const fullName = [
            user.nombre,
            user.apellido1,
            user.apellido2
        ]
            .filter(Boolean)
            .join(" ");

        const roleText = user.cod_rol?.descripcion || user.cod_rol || "-";
        const active = user.activo !== false;

        row.innerHTML = `
            <td>${escapeHtml(user.id)}</td>
            <td>${escapeHtml(user.usuario_red || "-")}</td>
            <td>${escapeHtml(fullName)}</td>
            <td>${escapeHtml(user.dni)}</td>
            <td>${escapeHtml(roleText)}</td>
            <td>
                <span class="status-badge ${
                    active
                        ? "status-active"
                        : "status-inactive"
                }">
                    ${active ? "Activo" : "Inactivo"}
                </span>
            </td>
            <td>
                <div class="action-buttons">
                    <button
                        class="btn btn-small btn-outline edit-user"
                        type="button">
                        Editar
                    </button>

                    <button
                        class="btn btn-small btn-danger delete-user"
                        type="button">
                        Eliminar
                    </button>
                </div>
            </td>
        `;

        row.querySelector(".edit-user").addEventListener(
            "click",
            () => openEditModal(user)
        );

        row.querySelector(".delete-user").addEventListener(
            "click",
            () => deleteUser(user)
        );

        usersTableBody.appendChild(row);
    });
}

function updateStats() {
    totalUsers.textContent = users.length;

    activeUsers.textContent = users.filter(
        (user) => user.activo !== false
    ).length;

    lastUpdate.textContent = new Date().toLocaleTimeString("es-CR", {
        hour: "2-digit",
        minute: "2-digit"
    });
}


/* ------------------------- Formulario ------------------------- */

function resetForm() {
    userForm.reset();

    document.getElementById("userId").value = "";

    document.getElementById("codProvincia").disabled = true;
    document.getElementById("codCanton").disabled = true;
    document.getElementById("codDistrito").disabled = true;

    phonesContainer.innerHTML = "";
    emailsContainer.innerHTML = "";
    websContainer.innerHTML = "";

    addPhoneRow();
    addEmailRow();
    addWebRow();

    modalTitle.textContent = "Nuevo usuario";
    document.getElementById("saveUserButton").textContent =
        "Guardar usuario";

    editingUser = null;
}

function openCreateModal() {
    resetForm();
    userModal.classList.remove("hidden");
}

function closeModal() {
    userModal.classList.add("hidden");
}

function openEditModal(user) {
    resetForm();

    editingUser = user;

    modalTitle.textContent = "Editar usuario";
    document.getElementById("saveUserButton").textContent =
        "Actualizar usuario";

    document.getElementById("userId").value = user.id;

    setValue("codRol", getRecordId(user.cod_rol));
    setValue("codTipoAuth", getRecordId(user.cod_tipo_auth));
    setValue(
        "codTipoIdentificacion",
        getRecordId(user.cod_tipo_identificacion)
    );

    setValue("dni", user.dni);
    setValue("nombre", user.nombre);
    setValue("apellido1", user.apellido1);
    setValue("apellido2", user.apellido2);

    setValue("codPais", getRecordId(user.cod_pais));
    setValue("codDepartamento", getRecordId(user.cod_departamento));

    setValue("codProvincia", getRecordId(user.cod_provincia));
    setValue("codCanton", getRecordId(user.cod_canton));
    setValue("codDistrito", getRecordId(user.cod_distrito));

    setValue("otrasSenas", user.otras_senas);
    setValue("usuarioRed", user.usuario_red);

    document.getElementById("activo").checked =
        user.activo !== false;

    userModal.classList.remove("hidden");
}

function setValue(id, value) {
    if (value !== null && value !== undefined) {
        document.getElementById(id).value = value;
    }
}

function collectUserData() {
    const data = {
        cod_rol: document.getElementById("codRol").value,
        cod_tipo_auth: document.getElementById("codTipoAuth").value,
        cod_tipo_identificacion:
            document.getElementById("codTipoIdentificacion").value,

        dni: document.getElementById("dni").value.trim(),
        nombre: document.getElementById("nombre").value.trim(),
        apellido1: document.getElementById("apellido1").value.trim(),
        apellido2: document.getElementById("apellido2").value.trim(),

        cod_pais: document.getElementById("codPais").value,
        cod_provincia: document.getElementById("codProvincia").value,
        cod_canton: document.getElementById("codCanton").value,
        cod_distrito: document.getElementById("codDistrito").value,

        otras_senas: document.getElementById("otrasSenas").value.trim(),
        imagen_path: null,

        cod_departamento:
            document.getElementById("codDepartamento").value || null,

        usuario_red:
            document.getElementById("usuarioRed").value.trim() || null,

        password_hash:
            document.getElementById("passwordHash").value || null,

        activo: document.getElementById("activo").checked,

        telefonos: collectPhones(),
        correos: collectEmails(),
        paginas_web: collectWebs()
    };

    return data;
}

async function saveUser(event) {
    event.preventDefault();

    const data = collectUserData();
    const userId = document.getElementById("userId").value;

    const url = userId
        ? `${API.usuarios}${userId}/`
        : API.usuarios;

    const method = userId ? "PATCH" : "POST";

    const button = document.getElementById("saveUserButton");
    button.disabled = true;

    try {
        await request(url, {
            method,
            headers: headers(true),
            body: JSON.stringify(data)
        });

        showAlert(
            userId
                ? "Usuario actualizado correctamente."
                : "Usuario creado correctamente."
        );

        closeModal();
        await loadUsers();
    } catch (error) {
        showAlert(
            `No se pudo guardar el usuario: ${error.message}`,
            "error"
        );
    } finally {
        button.disabled = false;
    }
}

async function deleteUser(user) {
    const confirmed = window.confirm(
        `¿Deseas eliminar al usuario ${user.nombre} ${user.apellido1 || ""}?`
    );

    if (!confirmed) {
        return;
    }

    try {
        await request(`${API.usuarios}${user.id}/`, {
            method: "DELETE",
            headers: headers()
        });

        showAlert("Usuario eliminado correctamente.");
        await loadUsers();
    } catch (error) {
        showAlert(
            `No se pudo eliminar el usuario: ${error.message}`,
            "error"
        );
    }
}


/* ------------------------- Filas dinámicas ------------------------- */

function addPhoneRow() {
    const row = document.createElement("div");
    row.className = "inline-row phone-row";

    row.innerHTML = `
        <select class="phone-type">
            <option value="">Tipo de teléfono</option>
            ${phoneTypes.map((item) => `
                <option value="${getRecordId(item)}">
                    ${escapeHtml(item.descripcion)}
                </option>
            `).join("")}
        </select>

        <input
            type="text"
            class="phone-number"
            placeholder="Número de teléfono"
            maxlength="25"
        >

        <button
            type="button"
            class="remove-button">
            ×
        </button>
    `;

    row.querySelector(".remove-button").addEventListener(
        "click",
        () => row.remove()
    );

    phonesContainer.appendChild(row);
}

function addEmailRow() {
    const row = document.createElement("div");
    row.className = "inline-row email-row";

    row.innerHTML = `
        <select class="email-type">
            <option value="">Tipo de correo</option>
            ${emailTypes.map((item) => `
                <option value="${getRecordId(item)}">
                    ${escapeHtml(item.descripcion)}
                </option>
            `).join("")}
        </select>

        <input
            type="email"
            class="email-address"
            placeholder="correo@ejemplo.com"
            maxlength="150"
        >

        <button
            type="button"
            class="remove-button">
            ×
        </button>
    `;

    row.querySelector(".remove-button").addEventListener(
        "click",
        () => row.remove()
    );

    emailsContainer.appendChild(row);
}

function addWebRow() {
    const row = document.createElement("div");
    row.className = "web-row";

    row.innerHTML = `
        <input
            type="url"
            class="web-url"
            placeholder="https://ejemplo.com"
            maxlength="255"
        >

        <button
            type="button"
            class="remove-button">
            ×
        </button>
    `;

    row.querySelector(".remove-button").addEventListener(
        "click",
        () => row.remove()
    );

    websContainer.appendChild(row);
}

function collectPhones() {
    return [...document.querySelectorAll(".phone-row")]
        .map((row) => ({
            cod_telefono: row.querySelector(".phone-type").value,
            telefono: row.querySelector(".phone-number").value.trim(),
            es_whatsapp: false
        }))
        .filter((item) => item.cod_telefono && item.telefono);
}

function collectEmails() {
    return [...document.querySelectorAll(".email-row")]
        .map((row) => ({
            cod_correo: row.querySelector(".email-type").value,
            correo: row.querySelector(".email-address").value.trim()
        }))
        .filter((item) => item.cod_correo && item.correo);
}

function collectWebs() {
    return [...document.querySelectorAll(".web-row")]
        .map((row) => ({
            url_web: row.querySelector(".web-url").value.trim()
        }))
        .filter((item) => item.url_web);
}


/* ------------------------- Eventos ------------------------- */

document
    .getElementById("newUserButton")
    .addEventListener("click", openCreateModal);

document
    .getElementById("closeModalButton")
    .addEventListener("click", closeModal);

document
    .getElementById("cancelButton")
    .addEventListener("click", closeModal);

document
    .getElementById("refreshButton")
    .addEventListener("click", loadUsers);

document
    .getElementById("addPhoneButton")
    .addEventListener("click", addPhoneRow);

document
    .getElementById("addEmailButton")
    .addEventListener("click", addEmailRow);

document
    .getElementById("addWebButton")
    .addEventListener("click", addWebRow);

document
    .getElementById("codPais")
    .addEventListener("change", loadProvinces);

document
    .getElementById("codProvincia")
    .addEventListener("change", loadCantons);

document
    .getElementById("codCanton")
    .addEventListener("change", loadDistricts);

document
    .getElementById("searchInput")
    .addEventListener("input", (event) => {
        const value = event.target.value.toLowerCase().trim();

        const filtered = users.filter((user) => {
            const text = [
                user.id,
                user.dni,
                user.nombre,
                user.apellido1,
                user.apellido2,
                user.usuario_red
            ]
                .filter(Boolean)
                .join(" ")
                .toLowerCase();

            return text.includes(value);
        });

        renderUsers(filtered);
    });

userForm.addEventListener("submit", saveUser);


/* ------------------------- Inicio ------------------------- */

(async function init() {
    await loadInitialCatalogs();
    resetForm();
    await loadUsers();
})();

const mobileMenuButton = document.getElementById("mobileMenuButton");
const sidebar = document.getElementById("sidebar");

if (mobileMenuButton && sidebar) {
    mobileMenuButton.addEventListener("click", () => {
        sidebar.classList.toggle("open");
    });
}