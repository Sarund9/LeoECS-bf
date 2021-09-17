// ----------------------------------------------------------------------------
// The MIT License
// Simple Entity Component System framework https://github.com/Leopotam/ecs
// Copyright (c) 2017-2021 Leopotam <leopotam@gmail.com>
// ----------------------------------------------------------------------------

using System;
using System.Collections;
using System.Reflection;

using internal Leopotam.Ecs;

namespace Leopotam.Ecs
{
    /// <summary>
    /// Base interface for all systems.
    /// </summary>
    public interface IEcsSystem { }

    /// <summary>
    /// Interface for PreInit systems. PreInit() will be called before Init().
    /// </summary>
    public interface IEcsPreInitSystem : IEcsSystem {
        void PreInit ();
    }

    /// <summary>
    /// Interface for Init systems. Init() will be called before Run().
    /// </summary>
    public interface IEcsInitSystem : IEcsSystem {
        void Init ();
    }

    /// <summary>
    /// Interface for PostDestroy systems. PostDestroy() will be called after Destroy().
    /// </summary>
    public interface IEcsPostDestroySystem : IEcsSystem {
        void PostDestroy ();
    }

    /// <summary>
    /// Interface for Destroy systems. Destroy() will be called last in system lifetime cycle.
    /// </summary>
    public interface IEcsDestroySystem : IEcsSystem {
        void Destroy ();
    }

    /// <summary>
    /// Interface for Run systems.
    /// </summary>
    public interface IEcsRunSystem : IEcsSystem {
        void Run ();
    }

#if !ECS_DISABLE_DEBUG_CHECKS
    /// <summary>
    /// Debug interface for systems events processing.
    /// </summary>
    public interface IEcsSystemsDebugListener {
        void OnSystemsDestroyed (EcsSystems systems);
    }
#endif

    /// <summary>
    /// Logical group of systems.
    /// </summary>

    public sealed class EcsSystems : IEcsInitSystem, IEcsDestroySystem, IEcsRunSystem
	{
        public readonly String Name;
        public readonly EcsWorld World;
        readonly EcsGrowList<IEcsSystem> _allSystems = new EcsGrowList<IEcsSystem> (64);
        readonly EcsGrowList<EcsSystemsRunItem> _runSystems = new EcsGrowList<EcsSystemsRunItem> (64);
        readonly Dictionary<int, int> _namedRunSystems = new Dictionary<int, int> (64);
        readonly Dictionary<Type, Object> _injections = new Dictionary<Type, Object> (32);
        bool _injected;
#if !ECS_DISABLE_DEBUG_CHECKS
        bool _initialized;
        bool _destroyed;
        readonly List<IEcsSystemsDebugListener> _debugListeners = new List<IEcsSystemsDebugListener> (4);

        /// <summary>
        /// Adds external event listener.
        /// </summary>
        /// <param name="listener">Event listener.</param>
        public void AddDebugListener (IEcsSystemsDebugListener listener)
		{
            /*if (listener == null) { throw new Exception ("listener is null"); }*/
			Runtime.Assert(listener != null, "listener is null");
            _debugListeners.Add (listener);
        }

        /// <summary>
        /// Removes external event listener.
        /// </summary>
        /// <param name="listener">Event listener.</param>
        public void RemoveDebugListener (IEcsSystemsDebugListener listener)
		{
            /*if (listener == null) { throw new Exception ("listener is null"); }*/
			Runtime.Assert(listener != null, "listener is null");
            _debugListeners.Remove (listener);
        }
#endif

        /// <summary>
        /// Creates new instance of EcsSystems group.
        /// </summary>
        /// <param name="world">EcsWorld instance.</param>
        /// <param name="name">Custom name for this group.</param>
        public this (EcsWorld world, String name = null)
		{
            World = world;
            Name = name;
        }

        /// <summary>
        /// Adds new system to processing.
        /// </summary>
        /// <param name="system">System instance.</param>
        /// <param name="namedRunSystem">Optional name of system.</param>
        public EcsSystems Add (IEcsSystem system, String namedRunSystem = null)
		{
#if !ECS_DISABLE_DEBUG_CHECKS
            /*if (system == null) { throw new Exception ("System is null."); }*/
			Runtime.Assert(system != null, "System is Null.");
            /*if (_initialized) { throw new Exception ("Cant add system after initialization."); }*/
			Runtime.Assert(!_initialized, "Cant add system after initialization");
            /*if (_destroyed) { throw new Exception ("Cant touch after destroy."); }*/
			Runtime.Assert(!_destroyed, "Cant touch after destroy.");
            /*if (!String.IsNullOrEmpty (namedRunSystem) && !(system is IEcsRunSystem)) { throw new Exception ("Cant name non-IEcsRunSystem."); }*/
			Runtime.Assert(String.IsNullOrEmpty (namedRunSystem) || (system is IEcsRunSystem), "Cant name non-IEcsRunSystem.");
#endif
            _allSystems.Add (system);
            if (system is IEcsRunSystem) {
                if (namedRunSystem == null && system is EcsSystems) {
                    namedRunSystem = (system as EcsSystems).Name;
                }
                if (namedRunSystem != null) {
#if !ECS_DISABLE_DEBUG_CHECKS
                    /*if (_namedRunSystems.ContainsKey (namedRunSystem.GetHashCode ())) {
                        throw new Exception ($"Cant add named system - \"{namedRunSystem}\" name already exists.");
                    }*/
					Runtime.Assert(!_namedRunSystems.ContainsKey (namedRunSystem.GetHashCode ()),
						scope $"Cant add named system - \"{namedRunSystem}\" name already exists.");
#endif
                    _namedRunSystems[namedRunSystem.GetHashCode ()] = _runSystems.Count;
                }
                _runSystems.Add (new EcsSystemsRunItem() { Active = true, System = (IEcsRunSystem) system });
            }
            return this;
        }

        public int GetNamedRunSystem (String name)
		{
			int idx;
            return _namedRunSystems.TryGetValue (name.GetHashCode (), out idx) ? idx : -1;
        }

        /// <summary>
        /// Sets IEcsRunSystem active state.
        /// </summary>
        /// <param name="idx">Index of system.</param>
        /// <param name="state">New state of system.</param>
        public void SetRunSystemState (int idx, bool state)
		{
#if !ECS_DISABLE_DEBUG_CHECKS
            /*if (idx < 0 || idx >= _runSystems.Count) { throw new Exception ("Invalid index"); }*/
			Runtime.Assert(!(idx < 0 || idx >= _runSystems.Count), "Invalid index"); // TODO: Proper Syntax
#endif
            _runSystems.Items[idx].Active = state;
        }

        /// <summary>
        /// Gets IEcsRunSystem active state.
        /// </summary>
        /// <param name="idx">Index of system.</param>
        public bool GetRunSystemState (int idx)
		{
#if !ECS_DISABLE_DEBUG_CHECKS
            /*if (idx < 0 || idx >= _runSystems.Count) { throw new Exception ("Invalid index"); }*/
			Runtime.Assert(!(idx < 0 || idx >= _runSystems.Count), "Invalid index");
#endif
            return _runSystems.Items[idx].Active;
        }

        /// <summary>
        /// Get all systems. Important: Don't change collection!
        /// </summary>
        public EcsGrowList<IEcsSystem> GetAllSystems ()
		{
            return _allSystems;
        }

        /// <summary>
        /// Gets all run systems. Important: Don't change collection!
        /// </summary>
        public EcsGrowList<EcsSystemsRunItem> GetRunSystems ()
		{
            return _runSystems;
        }

        /// <summary>
        /// Injects instance of object type to all compatible fields of added systems.
        /// </summary>
        /// <param name="obj">Instance.</param>
        /// <param name="overridenType">Overriden type, if null - typeof(obj) will be used.</param>
        public EcsSystems Inject (Object obj, Type overridenType = null)
		{
#if !ECS_DISABLE_DEBUG_CHECKS
            /*if (_initialized) { throw new Exception ("Cant inject after initialization."); }*/
			Runtime.Assert(!_initialized, "Cant inject after initialization.");
            /*if (obj == null) { throw new Exception ("Cant inject null instance."); }*/
			Runtime.Assert(obj != null, "Cant inject null instance");
            /*if (overridenType != null && !overridenType.IsInstanceOfType (obj)) { throw new Exception ("Invalid overriden type."); }*/
			Runtime.Assert(overridenType == null || overridenType.IsInstanceOfType (obj), "Invalid overriden type.");
#endif
			var oType = overridenType;
            if (oType == null) {
                oType = obj.GetType ();
            }
            _injections[oType] = obj;
            return this;
        }

        /// <summary>
        /// Processes injections immediately.
        /// Can be used to DI before Init() call.
        /// </summary>
        public EcsSystems ProcessInjects ()
		{
#if !ECS_DISABLE_DEBUG_CHECKS
            /*if (_initialized) { throw new Exception ("Cant inject after initialization."); }*/
			Runtime.Assert(!_initialized, "Cant inject after initialization.");
            /*if (_destroyed) { throw new Exception ("Cant touch after destroy."); }*/
			Runtime.Assert(!_destroyed, "Cant touch after destroy.");
#endif
            if (!_injected) {
                _injected = true;
                for (int i = 0, int iMax = _allSystems.Count; i < iMax; i++)
				{
                    if (_allSystems.Items[i] is EcsSystems)
					{
						let nestedSystems = _allSystems.Items[i] as EcsSystems;
                        for (var pair in _injections)
						{
                            nestedSystems._injections[pair.key] = pair.value;
                        }
                        nestedSystems.ProcessInjects ();
                    }
					else
					{
                        InjectDataToSystem (_allSystems.Items[i], World, _injections);
                    }
                }
            }
            return this;
        }

        /// <summary>
        /// Registers component type as one-frame for auto-removing at this point in execution sequence.
        /// </summary>
        public EcsSystems OneFrame<T> () where T : struct
		{
            return Add (new RemoveOneFrame<T> ());
        }

        /// <summary>
        /// Closes registration for new systems, initialize all registered.
        /// </summary>
        public void Init () {
#if !ECS_DISABLE_DEBUG_CHECKS
            /*if (_initialized) { throw new Exception ("Already initialized."); }*/
			Runtime.Assert(!_initialized, "Already initialized.");
            /*if (_destroyed) { throw new Exception ("Cant touch after destroy."); }*/
			Runtime.Assert(!_destroyed, "Cant touch after destroy.");
#endif
            ProcessInjects ();
            // IEcsPreInitSystem processing.
            for (int i = 0, int iMax = _allSystems.Count; i < iMax; i++) {
                var system = _allSystems.Items[i];
                if (system is IEcsPreInitSystem ) {
					let preInitSystem = system as IEcsPreInitSystem;
                    preInitSystem.PreInit ();
#if !ECS_DISABLE_DEBUG_CHECKS
                    World.CheckForLeakedEntities (scope $"{preInitSystem.GetType()}.PreInit()");
#endif
                }
            }
            // IEcsInitSystem processing.
            for (int i = 0, int iMax = _allSystems.Count; i < iMax; i++) {
                var system = _allSystems.Items[i];
                if (system is IEcsInitSystem ) {
					let initSystem = system as IEcsInitSystem;
                    initSystem.Init ();
#if !ECS_DISABLE_DEBUG_CHECKS
                    World.CheckForLeakedEntities (scope $"{initSystem.GetType()}.Init()");
#endif
                }
            }
#if !ECS_DISABLE_DEBUG_CHECKS
            _initialized = true;
#endif
        }

        /// <summary>
        /// Processes all IEcsRunSystem systems.
        /// </summary>
        public void Run () {
#if !ECS_DISABLE_DEBUG_CHECKS
            /*if (!_initialized) { throw new Exception ($"[{Name ?? "NONAME"}] EcsSystems should be initialized before."); }*/
			Runtime.Assert(_initialized,scope $"[{(Name ?? "NONAME")}] EcsSystems should be initialized before." );
            /*if (_destroyed) { throw new Exception ("Cant touch after destroy."); }*/
			Runtime.Assert(!_destroyed, "Cant touch after destroy.");
#endif
            for (int i = 0, int iMax = _runSystems.Count; i < iMax; i++)
			{
                var runItem = _runSystems.Items[i];
                if (runItem.Active) {
                    runItem.System.Run ();
                }
#if !ECS_DISABLE_DEBUG_CHECKS
                /*if (World.CheckForLeakedEntities (null))
				{
                    throw new Exception ($"Empty entity detected, possible memory leak in {_runSystems.Items[i].GetType ().Name}.Run ()");
                }*/
				Runtime.Assert(World.CheckForLeakedEntities (null),
					scope $"Empty entity detected, possible memory leak in {_runSystems.Items[i].GetType ()}.Run ()");
#endif
            }
        }

        /// <summary>
        /// Destroys registered data.
        /// </summary>
        public void Destroy () {
#if !ECS_DISABLE_DEBUG_CHECKS
            /*if (_destroyed) { throw new Exception ("Already destroyed."); }*/
			Runtime.Assert(!_destroyed, "Already destroyed.");
            _destroyed = true;
#endif
            // IEcsDestroySystem processing.
            for (var i = _allSystems.Count - 1; i >= 0; i--) {
                var system = _allSystems.Items[i];
                if (system is IEcsDestroySystem) {
					let destroySystem = system as IEcsDestroySystem;
                    destroySystem.Destroy ();
#if !ECS_DISABLE_DEBUG_CHECKS
                    World.CheckForLeakedEntities (scope $"{destroySystem.GetType ()}.Destroy ()");
#endif
                }
            }
            // IEcsPostDestroySystem processing.
            for (var i = _allSystems.Count - 1; i >= 0; i--) {
                var system = _allSystems.Items[i];
                if (system is IEcsPostDestroySystem) {
					let postDestroySystem = system as IEcsPostDestroySystem;
                    postDestroySystem.PostDestroy ();
#if !ECS_DISABLE_DEBUG_CHECKS
                    World.CheckForLeakedEntities (scope $"{postDestroySystem.GetType ()}.PostDestroy ()");
#endif
                }
            }
#if !ECS_DISABLE_DEBUG_CHECKS
            for (int i = 0, int iMax = _debugListeners.Count; i < iMax; i++) {
                _debugListeners[i].OnSystemsDestroyed (this);
            }
#endif
        }

        /// <summary>
        /// Injects custom data to fields of ISystem instance.
        /// </summary>
        /// <param name="system">ISystem instance.</param>
        /// <param name="world">EcsWorld instance.</param>
        /// <param name="injections">Additional instances for injection.</param>
        public static void InjectDataToSystem (IEcsSystem system, EcsWorld world, Dictionary<Type, Object> injections)
		{
            var systemType = system.GetType ();
            var worldType = world.GetType ();
            var filterType = typeof (EcsFilter);
            var ignoreType = typeof (EcsIgnoreInjectAttribute);

            for (var f in systemType.GetFields (BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance))
			{
                // skip statics or fields with [EcsIgnoreInject] attribute.
                if (f.IsStatic || Attribute.IsDefined (f, ignoreType)) {
                    continue;
                }
                // EcsWorld
                if (f.FieldType.IsAssignableFrom (worldType)) {
                    f.SetValue (system, world);
                    continue;
                }
                // EcsFilter
#if !ECS_DISABLE_DEBUG_CHECKS
                /*if (f.FieldType == filterType) {
                    throw new Exception ($"Cant use EcsFilter type at \"{system}\" system for dependency injection, use generic version instead");
                }*/
				Runtime.Assert(f.FieldType != filterType,
					scope $"Cant use EcsFilter type at \"{system}\" system for dependency injection, use generic version instead");
#endif
                if (f.FieldType.IsSubclassOf (filterType)) {
                    f.SetValue (system, world.GetFilter (f.FieldType));
                    continue;
                }
                // Other injections.
                for (var pair in injections)
				{
                    if (f.FieldType.IsAssignableFrom (pair.key)) {
                        f.SetValue (system, pair.value);
                        break;
                    }
                }
            }
        }
    }

    /// <summary>
    /// System for removing OneFrame component.
    /// </summary>
    /// <typeparam name="T">OneFrame component type.</typeparam>
    sealed class RemoveOneFrame<T> : IEcsRunSystem where T : struct
	{
        readonly EcsFilter<T> _oneFrames = null;

        void IEcsRunSystem.Run () {
            for (var idx = _oneFrames.GetEntitiesCount () - 1; idx >= 0; idx--) {
                _oneFrames.GetEntity (idx).Del<T> ();
            }
        }
    }

    /// <summary>
    /// IEcsRunSystem instance with active state.
    /// </summary>
    public sealed class EcsSystemsRunItem {
        public bool Active;
        public IEcsRunSystem System;
    }
}