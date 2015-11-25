module priority_queue;

class PriorityQueue(T,P) {
private:
    struct Elem {
        T data;
        P priority;
    };
    int     num;
    int     allocated;
    Elem[]  buffer;

    void resize(int newalloc) {
        buffer.length = newalloc;
        allocated = newalloc;
    }
    int find(T data) const {
        for (int i=1; i<num; ++i)
            if (buffer[i].data == data)
                return i;
        return 0;
    }
public:
    this(int size=4) {
        if (size<4) size = 4;
        buffer = new Elem[size];
        allocated = size;
        num = 1;
    }
    void purge() {
        num = 1;
    }
    int size() const {
        return num - 1;
    }
    bool is_in(T data) const {
        return (find(data) != 0);
    }
    bool change_priority(T data, P priority) {
        int i = find(data);
        if (!i) return false;
        if (buffer[i].priority < priority) {
            // ...
        } else if (buffer[i].priority > priority) {
            // ...
        } else {
            // ...
        }
        return true;
    }
    bool remove(T data) {
        int i = find(data);
        if (!i) return false;
        // ...
        return true;
    }
    void push(T data, P priority) {
        if (num >= allocated)
            resize(allocated*2);
        int m, n = num++;
        /* append at end, then up heap */
        while (((m=n/2) != 0) && (priority < buffer[m].priority)) {
            buffer[n] = buffer[m];
            n = m;
        }
        buffer[n].data = data;
        buffer[n].priority = priority;
    }
    P top_priority() const {
        return buffer[(num == 1) ? 0 : 1].priority;
    }
    T top() const {
        P priority;
        return top(priority);
    }
    T top(ref P priority) const {
        if (num == 1) {
            priority = buffer[0].priority;
            return cast(T)buffer[0].data;
        } else {
            priority = buffer[1].priority;
            return cast(T)buffer[1].data;
        }
    }
    T pop() {
        P priority;
        return pop(priority);
    }
    T pop(ref P priority) {
        if (num==1) return buffer[0].data;
        T out_data = buffer[1].data;
        priority = buffer[1].priority;
        /* pull last item to top, then down heap */
        --num;
        int n = 1, m;
        while ((m=n*2)<num) {
            if ((m+1 < num) && (buffer[m].priority > buffer[m+1].priority))
                ++m;
            if (buffer[num].priority <= buffer[m].priority)
                break;
            buffer[n] = buffer[m];
            n = m;
        }
        buffer[n] = buffer[num];
        //if (num < allocated/2 && num >= 16)
        //    resize(allocated/2);
        return out_data;
    }

    void combine(ref PriorityQueue!(T,P) pq) {
        for (int i=pq.num-1; i>=1; --i)
            push(pq.buffer[i].data, pq.buffer[i].priority);
        pq.purge();
    }
};
