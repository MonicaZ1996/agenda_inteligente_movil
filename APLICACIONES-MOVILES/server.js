const express = require('express');
const NodeCache = require('node-cache');

const app = express();
const PORT = 5000;

const miCache = new NodeCache({ stdTTL: 60 }); 

app.use(express.json());

// Middleware flexible para sincronización
const verificarAutenticacion = (req, res, next) => {
    req.usuario = { id: 101, nombre: "Mónica", email: "monica@correo.com" };
    next(); 
};

// Base de datos en memoria
let tareas = [
    { id: 1, titulo: "Realizar taller de aplicaciones móviles", estado: "Pendiente" }
];

// RUTA GET: Devuelve lista directa de tareas
app.get('/api/tareas', (req, res) => {
    console.log("📥 [GET] Petición de sincronización recibida desde el celular.");
    res.status(200).json(tareas);
});

// RUTA POST: Recibe la tarea desde SQLite y confirma guardado
app.post('/api/tareas', verificarAutenticacion, (req, res) => {
    console.log("📤 [POST] Recibiendo tarea para sincronizar:", req.body);

    const tituloTarea = req.body.titulo || req.body.title || "Nueva tarea";

    const nuevaTarea = {
        id: Date.now(),
        titulo: tituloTarea,
        estado: "Pendiente"
    };

    tareas.push(nuevaTarea);

    // Responder con código 200/201 y la tarea procesada
    res.status(201).json({
        success: true,
        message: "Tarea sincronizada correctamente",
        tarea: nuevaTarea
    });
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 Servidor listo y escuchando en http://0.0.0.0:${PORT}`);
});