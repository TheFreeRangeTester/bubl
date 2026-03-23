#!/usr/bin/env node

/**
 * Seed weekly bubls (and matching auth/public users) for demo/testing.
 *
 * Required env vars:
 * - SUPABASE_URL
 * - SUPABASE_SERVICE_ROLE_KEY
 *
 * Optional:
 * - BUBL_SEED_COUNT (default: curated dataset length)
 * - RESET_SEED=1 (delete current week's seed bubls before recreating them)
 */

const supabaseUrl = process.env.SUPABASE_URL;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const resetSeed = ["1", "true", "yes"].includes((process.env.RESET_SEED ?? "").toLowerCase());

if (!supabaseUrl || !serviceRoleKey) {
  console.error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
  process.exit(1);
}

const weekId = isoWeekId(new Date());
const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();

const curatedEntries = [
  {
    category: "work",
    subcategory: "work_career",
    topic: "promotion_review",
    activity_text: "Tuve mi evaluación anual y repasamos todo lo que hice liderando el proyecto de onboarding",
    feeling_text: "Salí con una mezcla rara de orgullo y duda, como si hubiera hecho mucho pero igual no fuera suficiente"
  },
  {
    category: "work",
    subcategory: "work_career",
    topic: "new_role",
    activity_text: "Arranqué en un rol nuevo y todavía estoy tratando de entender quién decide qué en el equipo",
    feeling_text: "Me siento medio perdido pero también con ganas de demostrar que puedo adaptarme rápido"
  },
  {
    category: "work",
    subcategory: "work_career",
    topic: "mentorship",
    activity_text: "Estoy mentoreando a alguien junior y me paso más tiempo explicando cosas básicas de lo que esperaba",
    feeling_text: "Me genera paciencia pero también cierta inseguridad sobre si estoy guiando bien"
  },
  {
    category: "work",
    subcategory: "work_burnout",
    topic: "meetings_overload",
    activity_text: "Esta semana tuve reuniones una atrás de otra y casi no toqué nada de código real",
    feeling_text: "Termino el día drenado sin sentir que avancé en nada concreto y eso me frustra bastante"
  },
  {
    category: "work",
    subcategory: "work_burnout",
    topic: "slack_noise",
    activity_text: "Tengo Slack explotando de mensajes todo el día y no logro concentrarme más de 15 minutos seguidos",
    feeling_text: "Siento que mi cabeza no descansa nunca y me cuesta cortar cuando termina el horario"
  },
  {
    category: "work",
    subcategory: "work_burnout",
    topic: "losing_focus",
    activity_text: "Intenté avanzar con una tarea importante pero me distraigo con cualquier cosa mínima",
    feeling_text: "Me frustra no poder entrar en foco como antes y me hace dudar de mi energía actual"
  },
  {
    category: "work",
    subcategory: "work_job_search",
    topic: "interview_prep",
    activity_text: "Estoy practicando entrevistas técnicas con ejercicios de lógica todas las noches",
    feeling_text: "Me da ansiedad pensar en la entrevista real pero también me motiva prepararme mejor"
  },
  {
    category: "work",
    subcategory: "work_job_search",
    topic: "cv_updates",
    activity_text: "Actualicé mi CV y LinkedIn tratando de que suene más claro lo que hago realmente",
    feeling_text: "Siento que vendo mejor mi perfil pero igual me cuesta creerme todo lo que puse"
  },
  {
    category: "work",
    subcategory: "work_job_search",
    topic: "rejections",
    activity_text: "Recibí dos rechazos seguidos después de avanzar bastante en procesos que me interesaban",
    feeling_text: "Me pegó más de lo que esperaba y me dejó cuestionando si estoy apuntando bien"
  },
  {
    category: "work",
    subcategory: "work_side_projects",
    topic: "building_app",
    activity_text: "Estoy armando una app chiquita en mis ratos libres y ya tengo el login funcionando",
    feeling_text: "Me entusiasma ver algo propio avanzar aunque me cueste mantener constancia"
  },
  {
    category: "work",
    subcategory: "work_side_projects",
    topic: "launching_product",
    activity_text: "Publiqué la primera versión de mi proyecto en línea y la compartí con amigos cercanos",
    feeling_text: "Me da miedo que no guste pero también alivio haberlo sacado del limbo"
  },
  {
    category: "work",
    subcategory: "work_side_projects",
    topic: "time_management",
    activity_text: "Intento dedicarle una hora diaria a mi side project después del trabajo",
    feeling_text: "A veces me cuesta arrancar pero cuando entro en ritmo me siento muy bien conmigo"
  },
  {
    category: "study",
    subcategory: "study_exams",
    topic: "finals_week",
    activity_text: "Estoy en semana de finales y paso el día entre resúmenes y repasos de último momento",
    feeling_text: "Siento la presión constante pero también una especie de adrenalina que me mantiene activo"
  },
  {
    category: "study",
    subcategory: "study_exams",
    topic: "failed_exam",
    activity_text: "Me fue mal en un examen que creía tener bastante controlado",
    feeling_text: "Me bajoneó más por la expectativa que tenía que por la nota en sí"
  },
  {
    category: "study",
    subcategory: "study_exams",
    topic: "last_minute",
    activity_text: "Estudié todo a último momento y terminé leyendo apuntes hasta la madrugada",
    feeling_text: "Sé que no es sostenible pero siempre termino cayendo en lo mismo"
  },
  {
    category: "study",
    subcategory: "study_skills",
    topic: "learning_code",
    activity_text: "Estoy aprendiendo TypeScript y me cuesta entender algunos tipos más avanzados",
    feeling_text: "Me frustra no agarrarlo rápido pero cada pequeño avance me motiva a seguir"
  },
  {
    category: "study",
    subcategory: "study_skills",
    topic: "practice_routine",
    activity_text: "Me propuse practicar una habilidad nueva todos los días aunque sea 20 minutos",
    feeling_text: "Me hace sentir consistente aunque algunos días lo haga sin muchas ganas"
  },
  {
    category: "study",
    subcategory: "study_skills",
    topic: "course_progress",
    activity_text: "Avancé varias lecciones de un curso online que tenía pausado hace meses",
    feeling_text: "Me da satisfacción retomar algo que había dejado colgado"
  },
  {
    category: "study",
    subcategory: "study_university",
    topic: "group_projects",
    activity_text: "Estoy en un trabajo grupal y cuesta coordinar horarios con todos",
    feeling_text: "Me agota la logística más que el contenido en sí"
  },
  {
    category: "study",
    subcategory: "study_university",
    topic: "campus_life",
    activity_text: "Volví a cursar presencial y estoy redescubriendo la rutina del campus",
    feeling_text: "Me gusta el movimiento pero también extraño la comodidad de casa"
  },
  {
    category: "study",
    subcategory: "study_university",
    topic: "assignments",
    activity_text: "Tengo varias entregas acumuladas y estoy tratando de organizarlas mejor",
    feeling_text: "Siento que voy corriendo atrás del tiempo constantemente"
  },
  {
    category: "study",
    subcategory: "study_languages",
    topic: "daily_practice",
    activity_text: "Estoy practicando inglés todos los días con podcasts mientras camino",
    feeling_text: "Siento pequeños avances que me dan confianza para seguir"
  },
  {
    category: "study",
    subcategory: "study_languages",
    topic: "speaking_anxiety",
    activity_text: "Intenté hablar con alguien nativo y me trabé más de lo que esperaba",
    feeling_text: "Me dio vergüenza pero también ganas de intentarlo de nuevo"
  },
  {
    category: "study",
    subcategory: "study_languages",
    topic: "vocabulary",
    activity_text: "Estoy usando flashcards para ampliar vocabulario en un idioma nuevo",
    feeling_text: "Es repetitivo pero veo progreso y eso me sostiene"
  },
  {
    category: "health",
    subcategory: "health_exercise",
    topic: "gym_routine",
    activity_text: "Volví al gimnasio y estoy tratando de sostener una rutina de tres veces por semana",
    feeling_text: "Me cuesta arrancar pero después me siento mucho mejor conmigo"
  },
  {
    category: "health",
    subcategory: "health_exercise",
    topic: "running",
    activity_text: "Salí a correr varias veces esta semana intentando mejorar mi ritmo",
    feeling_text: "Siento progreso pero también el cansancio acumulado en las piernas"
  },
  {
    category: "health",
    subcategory: "health_exercise",
    topic: "home_workout",
    activity_text: "Estoy haciendo ejercicios en casa con una rutina simple de YouTube",
    feeling_text: "Me gusta la flexibilidad pero a veces me falta motivación"
  },
  {
    category: "health",
    subcategory: "health_sleep",
    topic: "sleep_schedule",
    activity_text: "Intento acostarme más temprano pero siempre termino quedándome con el celular",
    feeling_text: "Me frustra no poder cortar a tiempo y levantarme cansado al otro día"
  },
  {
    category: "health",
    subcategory: "health_sleep",
    topic: "insomnia",
    activity_text: "Me cuesta dormir y me quedo dando vueltas pensando en cosas pendientes",
    feeling_text: "Es agotador no poder desconectar la cabeza cuando lo necesito"
  },
  {
    category: "health",
    subcategory: "health_sleep",
    topic: "nap_habits",
    activity_text: "Estoy intentando dejar las siestas largas para dormir mejor de noche",
    feeling_text: "Cuesta el cambio pero noto pequeñas mejoras"
  },
  {
    category: "relationships",
    subcategory: "relationships_partner",
    topic: "hard_conversation",
    activity_text: "Tuve una charla incómoda con mi pareja sobre cosas que veníamos pateando hace semanas",
    feeling_text: "Me dejó removido pero también con alivio de no seguir haciendo de cuenta que no pasaba nada"
  },
  {
    category: "relationships",
    subcategory: "relationships_partner",
    topic: "making_time",
    activity_text: "Estamos intentando reservar una noche para nosotros sin celulares ni pendientes de fondo",
    feeling_text: "Se siente simple pero nos cambia mucho el tono de la semana cuando realmente pasa"
  },
  {
    category: "relationships",
    subcategory: "relationships_partner",
    topic: "distance",
    activity_text: "Con mi pareja venimos cruzados de horarios y casi todo termina siendo logística",
    feeling_text: "Me da pena sentirnos tan funcionales cuando en realidad extraño conexión de verdad"
  },
  {
    category: "relationships",
    subcategory: "relationships_family",
    topic: "parents",
    activity_text: "Fui a almorzar con mis viejos y terminamos hablando de temas que solemos esquivar",
    feeling_text: "Salí medio cargado pero agradecido de que al menos se pudo hablar sin pelear"
  },
  {
    category: "relationships",
    subcategory: "relationships_family",
    topic: "caregiving",
    activity_text: "Estoy acompañando más a un familiar con temas de salud y me cambió bastante la rutina",
    feeling_text: "Lo hago con amor pero también siento un cansancio que me cuesta admitir"
  },
  {
    category: "relationships",
    subcategory: "relationships_family",
    topic: "siblings",
    activity_text: "Hablé con mi hermano después de bastante tiempo y fue raro retomar desde algo cotidiano",
    feeling_text: "Me quedó una mezcla de ternura y distancia, como si hubiera mucho debajo todavía"
  },
  {
    category: "relationships",
    subcategory: "relationships_friends",
    topic: "reconnecting",
    activity_text: "Volví a escribirle a una amiga que tenía muy colgada y terminamos poniéndonos al día horas",
    feeling_text: "Me hizo bien sentir que algunos vínculos sobreviven incluso cuando una desaparece un tiempo"
  },
  {
    category: "relationships",
    subcategory: "relationships_friends",
    topic: "group_dynamics",
    activity_text: "En mi grupo de amigos hay una tensión rara y todos estamos actuando como si nada",
    feeling_text: "Me agota esa incomodidad silenciosa porque se nota, aunque nadie la nombre"
  },
  {
    category: "relationships",
    subcategory: "relationships_friends",
    topic: "feeling_left_out",
    activity_text: "Vi planes entre amigos donde no estaba y me pegó más de lo que me gustaría admitir",
    feeling_text: "Sé que no siempre significa algo grave pero igual me despertó inseguridades viejas"
  },
  {
    category: "relationships",
    subcategory: "relationships_breakups",
    topic: "recent_breakup",
    activity_text: "Todavía estoy acomodándome después de cortar y me sorprende cuánto aparece en cosas mínimas",
    feeling_text: "Hay momentos de alivio real y otros donde me cae de golpe todo el vacío"
  },
  {
    category: "relationships",
    subcategory: "relationships_breakups",
    topic: "letting_go",
    activity_text: "Borré fotos y chats que venía guardando como una excusa para no cerrar del todo",
    feeling_text: "Me dolió hacerlo pero también sentí que por fin estaba soltando algo de verdad"
  },
  {
    category: "relationships",
    subcategory: "relationships_breakups",
    topic: "running_into_them",
    activity_text: "Me crucé con mi ex de casualidad y después me quedó el cuerpo raro todo el día",
    feeling_text: "No fue dramático pero me mostró que todavía hay cosas adentro que no terminé de ordenar"
  },
  {
    category: "creativity",
    subcategory: "creativity_writing",
    topic: "drafting",
    activity_text: "Estoy escribiendo algo personal y me trabo cada vez que siento que se está poniendo honesto",
    feeling_text: "Quiero seguir pero también me da pudor leerme tan de frente en una página"
  },
  {
    category: "creativity",
    subcategory: "creativity_writing",
    topic: "editing",
    activity_text: "Pasé la noche corrigiendo un texto viejo y tratando de decidir qué parte todavía me representa",
    feeling_text: "Es raro ver versiones de mí tan distintas y no saber si mejoré o sólo cambié de obsesiones"
  },
  {
    category: "creativity",
    subcategory: "creativity_writing",
    topic: "sharing_work",
    activity_text: "Le mostré algo que escribí a una persona de confianza después de tenerlo guardado meses",
    feeling_text: "Me dio vergüenza al instante pero también alivio de no seguir escondiéndolo"
  },
  {
    category: "creativity",
    subcategory: "creativity_design",
    topic: "client_feedback",
    activity_text: "Me llegó feedback de diseño con cambios razonables pero igual sentí que me desarmaban todo",
    feeling_text: "Sé separar trabajo y ego en teoría, pero algunas devoluciones igual me pegan bastante"
  },
  {
    category: "creativity",
    subcategory: "creativity_design",
    topic: "portfolio",
    activity_text: "Estoy ordenando mi portfolio y tratando de decidir qué trabajos siguen diciendo algo de mí",
    feeling_text: "Me entusiasma verlo tomar forma, aunque también me confronta con inseguridades viejas"
  },
  {
    category: "creativity",
    subcategory: "creativity_design",
    topic: "stuck_on_direction",
    activity_text: "Estoy probando direcciones visuales para un proyecto y ninguna me termina de cerrar del todo",
    feeling_text: "Se siente frustrante pero también sé que esta parte confusa suele venir antes de algo bueno"
  },
  {
    category: "creativity",
    subcategory: "creativity_drawing",
    topic: "daily_sketches",
    activity_text: "Volví a hacer dibujos rápidos todas las noches aunque sea media hora",
    feeling_text: "No me salen increíbles pero me está devolviendo una relación más liviana con dibujar"
  },
  {
    category: "creativity",
    subcategory: "creativity_drawing",
    topic: "finishing_piece",
    activity_text: "Estoy intentando terminar una ilustración que vengo pateando porque siempre le encuentro algo mal",
    feeling_text: "Me cuesta soltarla, como si cerrarla significara aceptar también sus imperfecciones"
  },
  {
    category: "creativity",
    subcategory: "creativity_drawing",
    topic: "style_search",
    activity_text: "Ando probando estilos distintos de dibujo y siento que todavía no encuentro uno que se sienta mío",
    feeling_text: "A veces eso me entusiasma y otras me hace sentir medio disperso con lo que hago"
  },
  {
    category: "creativity",
    subcategory: "creativity_music",
    topic: "guitar_practice",
    activity_text: "Retomé la guitarra esta semana y estoy tratando de recuperar agilidad en los dedos",
    feeling_text: "Me frustra no tocar como antes pero también me emociona volver a escucharme avanzar"
  },
  {
    category: "creativity",
    subcategory: "creativity_music",
    topic: "recording_demo",
    activity_text: "Grabé una demo casera de una idea que venía dando vueltas en mi cabeza hace meses",
    feeling_text: "Suena más cruda de lo que imaginaba, pero me hizo bien sacarla del plano mental"
  },
  {
    category: "creativity",
    subcategory: "creativity_music",
    topic: "stuck_on_song",
    activity_text: "Tengo una canción a medio armar y cada vez que me siento a seguirla me quedo en blanco",
    feeling_text: "Es de esos bloqueos que me irritan porque sé que algo está ahí pero no logro abrirlo"
  },
  {
    category: "hobbies",
    subcategory: "music",
    topic: "live_shows",
    activity_text: "Estoy escuchando en loop la banda que voy a ver en noviembre para llegar al show con todo fresco",
    feeling_text: "Me sube el ánimo tener esa fecha en el calendario y fantasear un poco con cómo va a sonar en vivo"
  },
  {
    category: "hobbies",
    subcategory: "music",
    topic: "playlists",
    activity_text: "Armé una playlist nueva para caminar de noche y estoy obsesionado con cómo quedó el mood",
    feeling_text: "Me encanta cuando una secuencia de temas parece ordenar el ruido que tengo adentro"
  },
  {
    category: "hobbies",
    subcategory: "music",
    topic: "artist_fandom",
    activity_text: "Volví a escuchar discografías enteras de una banda y me agarró esa fijación hermosa de adolescencia",
    feeling_text: "Hay algo muy reconfortante en dejarme absorber por un sonido conocido cuando todo lo demás cambia"
  },
  {
    category: "hobbies",
    subcategory: "gaming",
    topic: "cozy_games",
    activity_text: "Estoy jugando un rato de Stardew Valley a la noche para bajar un cambio después del trabajo",
    feeling_text: "Es de las pocas cosas que me apagan el ruido mental sin exigirme nada a cambio"
  },
  {
    category: "hobbies",
    subcategory: "gaming",
    topic: "survival_horror",
    activity_text: "Le metí varias horas a un survival horror esta semana y terminé mucho más tenso de lo esperado",
    feeling_text: "La paso bien pero quedo con el cuerpo acelerado incluso después de apagar la consola"
  },
  {
    category: "hobbies",
    subcategory: "gaming",
    topic: "old_favorite",
    activity_text: "Volví a un juego que me encantaba hace años para ver si todavía me hacía sentir lo mismo",
    feeling_text: "Hay nostalgia, pero también cierta tristeza por notar cuánto cambió mi forma de habitar esos mundos"
  },
  {
    category: "hobbies",
    subcategory: "food",
    topic: "home_cooking",
    activity_text: "Estoy cocinando más en casa y probando recetas simples para no caer siempre en lo mismo",
    feeling_text: "Me ordena bastante el día tener aunque sea una comida hecha por mí con cierta intención"
  },
  {
    category: "hobbies",
    subcategory: "food",
    topic: "baking",
    activity_text: "Hice algo al horno por primera vez en meses y me salió mejor de lo que esperaba",
    feeling_text: "Ese tipo de logro doméstico mínimo me levanta mucho más de lo que debería"
  },
  {
    category: "hobbies",
    subcategory: "food",
    topic: "trying_places",
    activity_text: "Fui a probar un lugar nuevo de ramen y me quedé pensando en eso más tiempo del necesario",
    feeling_text: "Me hizo bien tener una salida simple que no girara alrededor de trabajar o resolver cosas"
  },
  {
    category: "hobbies",
    subcategory: "sports",
    topic: "playing_match",
    activity_text: "Jugué un partido con amigos después de bastante tiempo sin moverme así",
    feeling_text: "Terminé destruido físicamente pero con una energía muy distinta a la del resto de la semana"
  },
  {
    category: "hobbies",
    subcategory: "sports",
    topic: "watching_team",
    activity_text: "Estuve siguiendo a mi equipo toda la semana y me afecta demasiado cada resultado",
    feeling_text: "Sé que es irracional pero me cambia muchísimo el humor cuando juegan bien o mal"
  },
  {
    category: "hobbies",
    subcategory: "sports",
    topic: "learning_sport",
    activity_text: "Estoy intentando engancharme con un deporte nuevo y todavía me siento bastante torpe",
    feeling_text: "Me da un poco de vergüenza no entender códigos básicos, aunque también me divierte ser principiante"
  },
  {
    category: "hobbies",
    subcategory: "reading",
    topic: "novel",
    activity_text: "Arranqué una novela y me está pasando eso hermoso de querer volver a leer apenas tengo un rato libre",
    feeling_text: "Se siente como recuperar una atención más profunda que extrañaba bastante"
  },
  {
    category: "hobbies",
    subcategory: "reading",
    topic: "nonfiction",
    activity_text: "Estoy leyendo ensayo antes de dormir y a veces termino subrayando más de la cuenta",
    feeling_text: "Me gusta cuando una idea me sigue acompañando al día siguiente como ruido bueno"
  },
  {
    category: "hobbies",
    subcategory: "reading",
    topic: "reading_slump",
    activity_text: "Tengo varios libros empezados y no logro quedarme con ninguno del todo",
    feeling_text: "Me frustra sentir ganas de leer pero no poder engancharme en serio con nada"
  },
  {
    category: "hobbies",
    subcategory: "hobbies_other",
    topic: "collecting",
    activity_text: "Estuve ordenando una colección vieja que tenía desparramada y me absorbió más de lo esperado",
    feeling_text: "Hay algo muy calmante en dedicarle tiempo a un interés que no necesita justificar su utilidad"
  },
  {
    category: "hobbies",
    subcategory: "hobbies_other",
    topic: "weekend_project",
    activity_text: "Me puse con un proyecto manual de fin de semana sólo para hacer algo con las manos",
    feeling_text: "No salió perfecto pero me devolvió una sensación de presencia que venía extrañando"
  },
  {
    category: "hobbies",
    subcategory: "hobbies_other",
    topic: "rediscovering_interest",
    activity_text: "Estoy retomando un hobby que había dejado por años y me sorprende lo familiar que se siente",
    feeling_text: "Me da alegría volver a algo que no tiene presión de rendimiento ni productividad"
  },
  {
    category: "life",
    subcategory: "life_moving",
    topic: "packing",
    activity_text: "Empecé a empacar de a poco porque me mudo en unas semanas y ya tengo la casa medio desarmada",
    feeling_text: "Me entusiasma el cambio pero también me genera una ansiedad rara ver todo en transición"
  },
  {
    category: "life",
    subcategory: "life_moving",
    topic: "new_place",
    activity_text: "Fui a ver el lugar al que me voy a mudar y recién ahí sentí que esto está pasando de verdad",
    feeling_text: "Tengo emoción genuina mezclada con miedo de no sentirme en casa tan rápido como quisiera"
  },
  {
    category: "life",
    subcategory: "life_moving",
    topic: "letting_go_space",
    activity_text: "Estoy vaciando cosas de mi cuarto y aparecieron recuerdos que no esperaba encontrar ahora",
    feeling_text: "Me pegó más desde lo emocional que desde la logística, como cerrar una etapa entera"
  },
  {
    category: "life",
    subcategory: "life_organization",
    topic: "decluttering",
    activity_text: "Me puse a ordenar papeles, cajones y pendientes mínimos que venía pateando hace meses",
    feeling_text: "No resuelve todo pero me baja muchísimo la ansiedad ver menos caos alrededor"
  },
  {
    category: "life",
    subcategory: "life_organization",
    topic: "routine_reset",
    activity_text: "Estoy tratando de armar una rutina más estable porque venía viviendo demasiado improvisado",
    feeling_text: "Me cuesta sostenerla, pero cuando sale siento que mi cabeza afloja bastante"
  },
  {
    category: "life",
    subcategory: "life_organization",
    topic: "digital_cleanup",
    activity_text: "Hice limpieza de archivos, notas y mails viejos como si estuviera ordenando también la cabeza",
    feeling_text: "Es medio ridículo cuánto alivio me da cerrar pestañas que ni sabía que me pesaban"
  },
  {
    category: "life",
    subcategory: "life_finances",
    topic: "budgeting",
    activity_text: "Me senté a mirar gastos con más detalle porque sentía que la plata se me estaba yendo por todos lados",
    feeling_text: "No fue divertido pero me dio una sensación de control que necesitaba hace rato"
  },
  {
    category: "life",
    subcategory: "life_finances",
    topic: "big_expense",
    activity_text: "Tuve un gasto grande e inesperado y me desacomodó bastante más el mes de lo que quería admitir",
    feeling_text: "Intento no dramatizarlo, pero me deja ese fondo de preocupación que tarda en aflojar"
  },
  {
    category: "life",
    subcategory: "life_finances",
    topic: "saving_goal",
    activity_text: "Estoy intentando ahorrar con un objetivo concreto y me obliga a pensar más cada compra boluda",
    feeling_text: "A veces me pesa limitarme, pero también me gusta sentir que me estoy cuidando a futuro"
  },
  {
    category: "life",
    subcategory: "life_decisions",
    topic: "major_choice",
    activity_text: "Tengo que tomar una decisión importante y vengo dándole vueltas sin poder cerrar nada",
    feeling_text: "Me desgasta sentir que cualquier opción deja algo valioso afuera"
  },
  {
    category: "life",
    subcategory: "life_decisions",
    topic: "saying_no",
    activity_text: "Dije que no a algo que parecía razonable desde afuera pero que a mí me drenaba demasiado",
    feeling_text: "Me quedó culpa al principio, aunque también una paz bastante inmediata en el cuerpo"
  },
  {
    category: "life",
    subcategory: "life_decisions",
    topic: "next_step",
    activity_text: "Estoy tratando de definir cuál debería ser mi próximo paso en algo que ya no quiero seguir pateando",
    feeling_text: "No tengo claridad total, pero al menos empecé a aceptar que decidir también es parte del alivio"
  }
];

const totalCount = Number.parseInt(process.env.BUBL_SEED_COUNT ?? String(curatedEntries.length), 10);

if (!Number.isFinite(totalCount) || totalCount < 3) {
  console.error("BUBL_SEED_COUNT must be >= 3");
  process.exit(1);
}

const generated = buildSeedEntries(curatedEntries, totalCount);

async function main() {
  const existingSeedUsers = await listAllSeedUsers();

  if (resetSeed) {
    console.log(`Reset mode enabled. Deleting seed bubls for week ${weekId}...`);
    const deleted = await deleteExistingSeedBublsForWeek(existingSeedUsers, weekId);
    console.log(`Deleted seed bubls for week ${weekId}: ${deleted}`);
  }

  console.log(`Seeding ${generated.length} bubls for week ${weekId}...`);

  for (let i = 0; i < generated.length; i += 1) {
    const entry = generated[i];
    const email = `seed-${String(i + 1).padStart(3, "0")}@bubl.local`;
    const password = `Seed!Week${weekId.replace("-", "")}!${i}`;

    const authUser = await getOrCreateAuthUser(email, password, entry.locale, existingSeedUsers);
    const userId = authUser.id;

    await upsertPublicUser(userId, entry.locale);
    await insertBubl(userId, entry, weekId, expiresAt);

    if ((i + 1) % 20 === 0 || i + 1 === generated.length) {
      console.log(`  -> ${i + 1}/${generated.length}`);
    }
  }

  console.log("Seed completed.");
  console.log(`Seed users available: ${existingSeedUsers.size}`);
  console.log(`Created bubls: ${generated.length}`);
}

async function listAuthUsers(page, perPage) {
  const url = new URL(`${supabaseUrl}/auth/v1/admin/users`);
  url.searchParams.set("page", String(page));
  url.searchParams.set("per_page", String(perPage));

  const resp = await fetch(url.toString(), {
    method: "GET",
    headers: {
      apikey: serviceRoleKey,
      Authorization: `Bearer ${serviceRoleKey}`,
      "Content-Type": "application/json"
    }
  });

  const payload = await parseJson(resp);
  if (!resp.ok) {
    throw new Error(`listAuthUsers failed: ${resp.status} ${JSON.stringify(payload)}`);
  }

  return payload.users ?? [];
}

async function listAllSeedUsers() {
  let page = 1;
  const perPage = 200;
  const usersByEmail = new Map();

  while (true) {
    const users = await listAuthUsers(page, perPage);
    if (users.length === 0) break;

    for (const user of users) {
      if ((user.email ?? "").endsWith("@bubl.local")) {
        usersByEmail.set(user.email, user);
      }
    }

    if (users.length < perPage) break;
    page += 1;
  }

  return usersByEmail;
}

async function deleteExistingSeedBublsForWeek(existingSeedUsers, week_id) {
  let deleted = 0;

  for (const user of existingSeedUsers.values()) {
    deleted += await deleteBublsForUserWeek(user.id, week_id);
  }

  return deleted;
}

async function deleteBublsForUserWeek(userId, week_id) {
  const url = new URL(`${supabaseUrl}/rest/v1/bubls`);
  url.searchParams.set("user_id", `eq.${userId}`);
  url.searchParams.set("week_id", `eq.${week_id}`);

  const resp = await fetch(url.toString(), {
    method: "DELETE",
    headers: {
      apikey: serviceRoleKey,
      Authorization: `Bearer ${serviceRoleKey}`,
      "Content-Type": "application/json",
      Prefer: "return=representation"
    }
  });

  const payload = await parseJson(resp);
  if (!resp.ok) {
    throw new Error(`deleteBublsForUserWeek failed: ${resp.status} ${JSON.stringify(payload)}`);
  }

  return Array.isArray(payload) ? payload.length : 0;
}

async function getOrCreateAuthUser(email, password, locale, existingSeedUsers) {
  const existing = existingSeedUsers.get(email);
  if (existing) {
    return existing;
  }

  const created = await createAuthUser(email, password, locale);
  existingSeedUsers.set(email, created);
  return created;
}

async function createAuthUser(email, password, locale) {
  const resp = await fetch(`${supabaseUrl}/auth/v1/admin/users`, {
    method: "POST",
    headers: {
      apikey: serviceRoleKey,
      Authorization: `Bearer ${serviceRoleKey}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      email,
      password,
      email_confirm: true,
      user_metadata: { seed: true, locale }
    })
  });

  const payload = await parseJson(resp);
  if (!resp.ok) {
    throw new Error(`createAuthUser failed: ${resp.status} ${JSON.stringify(payload)}`);
  }
  return payload;
}

async function upsertPublicUser(userId, locale) {
  const resp = await fetch(`${supabaseUrl}/rest/v1/users`, {
    method: "POST",
    headers: {
      apikey: serviceRoleKey,
      Authorization: `Bearer ${serviceRoleKey}`,
      "Content-Type": "application/json",
      Prefer: "resolution=merge-duplicates,return=representation"
    },
    body: JSON.stringify([{ id: userId, locale }])
  });

  const payload = await parseJson(resp);
  if (!resp.ok) {
    throw new Error(`upsertPublicUser failed: ${resp.status} ${JSON.stringify(payload)}`);
  }
  return payload;
}

async function insertBubl(userId, entry, week_id, expires_at) {
  const resp = await fetch(`${supabaseUrl}/rest/v1/bubls`, {
    method: "POST",
    headers: {
      apikey: serviceRoleKey,
      Authorization: `Bearer ${serviceRoleKey}`,
      "Content-Type": "application/json",
      Prefer: "return=representation"
    },
    body: JSON.stringify([
      {
        user_id: userId,
        activity_text: entry.activity_text,
        feeling_text: entry.feeling_text,
        cluster_label: entry.cluster_label,
        action: entry.action,
        topic: entry.topic,
        tags: entry.tags,
        week_id,
        expires_at,
        is_active: true,
        is_flagged: false
      }
    ])
  });

  const payload = await parseJson(resp);
  if (!resp.ok) {
    throw new Error(`insertBubl failed: ${resp.status} ${JSON.stringify(payload)}`);
  }
  return payload;
}

function buildSeedEntries(entries, count) {
  if (count <= entries.length) {
    return entries.slice(0, count).map(normalizeEntry);
  }

  const generated = [];
  for (let i = 0; i < count; i += 1) {
    const base = normalizeEntry(entries[i % entries.length]);

    if (i < entries.length) {
      generated.push(base);
      continue;
    }

    generated.push({
      ...base,
      activity_text: `${base.activity_text} (${ordinal(i - entries.length + 1)} seed variant)`
    });
  }

  return generated;
}

function normalizeEntry(entry) {
  return {
    activity_text: entry.activity_text,
    feeling_text: entry.feeling_text,
    cluster_label: entry.cluster_label ?? entry.subcategory ?? null,
    action: inferAction(entry.subcategory ?? entry.cluster_label ?? entry.category),
    topic: entry.topic ?? inferTopic(entry.subcategory ?? entry.cluster_label ?? entry.category),
    tags: inferTags(entry),
    locale: entry.locale ?? "es"
  };
}

function inferAction(subcategory) {
  if (!subcategory) return "other";
  if (subcategory.startsWith("work_")) return "working_on";
  if (subcategory.startsWith("study_")) return "learning";
  if (subcategory.startsWith("health_")) return "caring";
  if (subcategory.startsWith("relationships_")) return "caring";
  if (subcategory.startsWith("creativity_")) return "creating";
  if (subcategory === "music") return "listening";
  if (subcategory === "gaming") return "playing";
  if (subcategory === "food") return "cooking";
  if (subcategory === "sports") return "training";
  return "other";
}

function inferTopic(subcategory) {
  if (!subcategory) return "general";
  return subcategory.replace(/^(work|study|health|relationships|creativity|life)_/, "");
}

function inferTags(entry) {
  return [entry.category, entry.subcategory, entry.topic]
    .filter(Boolean)
    .map((value) => String(value));
}

async function parseJson(resp) {
  const text = await resp.text();
  if (!text) return {};
  try {
    return JSON.parse(text);
  } catch {
    return { raw: text };
  }
}

function isoWeekId(date) {
  const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
  const day = d.getUTCDay() || 7;
  d.setUTCDate(d.getUTCDate() + 4 - day);
  const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
  const weekNo = Math.ceil((((d - yearStart) / 86400000) + 1) / 7);
  return `${d.getUTCFullYear()}-${String(weekNo).padStart(2, "0")}`;
}

function ordinal(n) {
  const s = ["th", "st", "nd", "rd"];
  const v = n % 100;
  return `${n}${s[(v - 20) % 10] || s[v] || s[0]}`;
}

main().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
