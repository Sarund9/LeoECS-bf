// ----------------------------------------------------------------------------
// The MIT License
// Simple Entity Component System framework https://github.com/Leopotam/ecs
// Copyright (c) 2017-2021 Leopotam <leopotam@gmail.com>
// ----------------------------------------------------------------------------

using System;

using internal Leopotam.Ecs;

//Added in Beef
namespace System
{
	extension Object
	{
		internal String ToNewString(int bufferSize = 64)
		{
			String str = scope String(bufferSize);
			ToString(str);
			return str;
		}
	}

	// Equivalent C# Type Methods
	extension Type
	{
		internal bool IsAssignableFrom(Type type)
		{
			Runtime.Assert(false, "Not Implemented");

			

			return false;
		}

		internal Type GetInterface(String name)
		{
			String buffer = "";
			for (let i in this.Interfaces)
			{
				i.GetName(buffer);

				if (buffer == name)
				{
					return i;
				}

				buffer.Clear();
			}
			return null;
		}

		internal bool IsAtrDefined()
		{

			return false;
		}

		/*internal bool IsSubclassOf(Type type)
		{
			Runtime.Assert(false, "Not Implemented");

			/*this.*/

			return false;
		}*/
	}
}

namespace Leopotam.Ecs {

	public static class Util
	{
		public static void ResizeArray<T>(ref T[] array, int size)
		{
			Runtime.Assert(size >= 0, "Array Resize must be greater than 0");

			if (array.Count == size)
				return;

			T[] newArray = scope T[size];

			for (int i < Math.Min(size, array.Count))
			{
				newArray[i] = array[i];
			}
			
			array = newArray;
		}
	}

    /// <summary>
    /// Fast List replacement for growing only collections.
    /// </summary>
    /// <typeparam name="T">Type of item.</typeparam>
    public class EcsGrowList<T>
	{
        public T[] Items;
        public int Count;

        /*[MethodImpl (MethodImplOptions.AggressiveInlining)]*/
		[Inline]
        public this (int capacity)
		{
#if !ECS_DISABLE_DEBUG_CHECKS
            /*if (capacity <= 0) { throw new Exception ("Capacity should be greater than zero."); }*/
			Runtime.Assert(capacity > 0, "Capacity should be greater than zero.");
#endif
            Items = new T[capacity];
            Count = 0;
        }

        /*[MethodImpl (MethodImplOptions.AggressiveInlining)]*/
		[Inline]
        public void Add (T item)
		{
            if (Items.Count == Count) {
                Util.ResizeArray(ref Items, Items.Count << 1);
            }
            Items[Count++] = item;
        }

        /*[MethodImpl (MethodImplOptions.AggressiveInlining)]*/
		[Inline]
        public void EnsureCapacity (int count)
		{
            if (Items.Count < count) {
                var len = Items.Count << 1;
                while (len <= count) {
                    len <<= 1;
                }
                Util.ResizeArray(ref Items, len);
            }
        }
    }
}

