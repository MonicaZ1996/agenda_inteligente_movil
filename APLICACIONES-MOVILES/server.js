const express = require('express');
const NodeCache = require('node-cache'); // 1. Importamos la librería de caché

const app = express();
const PORT = 5000;

// 2. Inicializamos la caché. TTL es el tiempo de vida (Time To Live) en segundos (ej. 60 segundos)
const miCache = new NodeCache({ stdTTL: 60 }); 

app.use(express.json());

// Base de datos simulada
let usuarios = [
    { id: 101, nombre: "Mónica", email: "monica@correo.com" },
    { id: 102, nombre: "Juan", email: "juan@correo.com" }
];

let tareas = [
    { id: 1, titulo: "Realizar taller de aplicaciones móviles", estado: "Pendiente", usuarioId: 101 },
    { id: 2, titulo: "Estudiar para el examen de backend", estado: "Pendiente", usuarioId: 102 },
    { id: 3, titulo: "Subir repositorio a GitHub", estado: "Completada", usuarioId: 101 }
];

// ====================================================================
// PASO 5: MIDDLEWARE DE AUTENTICACIÓN OPTIMIZADO (¡Aquí va acomodado!)
// ====================================================================
const verificarAutenticacion = (req, res, next) => {
    const token = req.headers['authorization'];

    if (!token || token !== 'Bearer token_secreto_monica') {
        return res.status(401).json({ error: "Acceso no autorizado. Token inválido o ausente." });
    }

    console.log("🛡️ [Middleware] Usuario autenticado con éxito.");
    console.log("🚀 [Optimización] Información guardada en 'req.usuario' para evitar consultas redundantes.");

    req.usuario = {
        id: 101,
        nombre: "Mónica",
        email: "monica@correo.com"
    };

    next(); 
};

// ====================================================================
// RUTA GET OPTIMIZADA (CORRECCIÓN N+1 MEDIANTE EAGER LOADING SIMULADO)
// ====================================================================
app.get('/api/tareas', (req, res) => {
    const tareasGuardadas = miCache.get('lista_tareas');
    if (tareasGuardadas) {
        console.log("⚡ Servido desde la CACHÉ");
        return res.json(tareasGuardadas);
    }

    console.log("🔍 Cache Miss. Procesando consulta optimizada con Eager Loading...");
    console.time("Tiempo Eager Loading");

    const usuariosMap = usuarios.reduce((map, usuario) => {
        map[usuario.id] = usuario;
        return map;
    }, {});

    const resultado = tareas.map(tarea => {
        return {
            id: tarea.id,
            titulo: tarea.titulo,
            estado: tarea.estado,
            usuario: usuariosMap[tarea.usuarioId] || null 
        };
    });

    console.timeEnd("Tiempo Eager Loading");

    miCache.set('lista_tareas', resultado);
    res.json(resultado);
});

// ====================================================================
// RUTA POST PROTEGIDA Y CON TRABAJO ASÍNCRONO
// ====================================================================
app.post('/api/tareas', verificarAutenticacion, (req, res) => {
    if (!req.body || !req.body.titulo) {
        return res.status(400).json({ error: "El campo 'titulo' es obligatorio." });
    }

    const nuevaTarea = {
        id: tareas.length > 0 ? tareas[tareas.length - 1].id + 1 : 1,
        titulo: req.body.titulo,
        estado: "Pendiente",
        usuarioId: req.usuario.id 
    };

    tareas.push(nuevaTarea);
    miCache.del('lista_tareas'); 

    console.log(`📩 [API] Tarea #${nuevaTarea.id} creada por el usuario: ${req.usuario.nombre}`);
    
    setTimeout(() => {
        console.log("----------------------------------------------------------------");
        console.log(`⚙️ [Worker Asíncrono] Enviando correo de confirmación a: ${req.usuario.email}...`);
        console.log(`✅ [Worker Asíncrono] Notificación enviada con éxito.`);
        console.log("----------------------------------------------------------------");
    }, 4000); 

    res.status(201).json({
        mensaje: "Tarea creada correctamente y notificación encolada.",
        tarea: nuevaTarea
    });
});

// Inicialización del servidor
const PORT = process.env.PORT || 5000;

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Servidor ejecutándose correctamente en http://0.0.0.0:${PORT}`);
});