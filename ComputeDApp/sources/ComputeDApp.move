module 0x1::ComputeDApp {
    use std::signer;
    use std::vector;
    use std::option::{self, Option};
    use std::assert;
    use aptos_framework::event;

    struct Provider has copy, drop, store {
        provider_address:address,
        active:bool,
    }

    struct Task has copy, drop, store {
        id:u64,
        requester:address,
        provider_id:u64,
        task_data:vector<u8>,
        result:vector<u8>,
        completed:bool,
    }

    struct BalanceEntry has copy, drop, store {
        owner:address,
        balance:u64,
    }

    struct ProviderRegisteredEvent has copy, drop, store {
        provider_id:u64,
        provider:address,
    }

    struct TaskRequestedEvent has copy, drop, store {
        task_id:u64,
        provider_id:u64,
        requester:address,
        task_data:vector<u8>,
    }

    struct TaskCompletedEvent has copy, drop, store {
        task_id:u64,
        provider_id:u64,
        result:vector<u8>,
    }

    struct ComputeDAppData has key {
        providers: vector<Provider>,
        tasks: vector<Task>,
        balances: vector<BalanceEntry>,
        next_task_id: u64,
        provider_registered_events: event::EventHandle<ProviderRegisteredEvent>,
        task_requested_events: event::EventHandle<TaskRequestedEvent>,
        task_completed_events: event::EventHandle<TaskCompletedEvent>,
    }

    public fun init(account: &signer) {
        assert!(!exists<ComputeDAppData>(@0x1), 1);
        move_to(account, ComputeDAppData {
            providers:vector::empty<Provider>(),
            tasks:vector::empty<Task>(),
            balances:vector::empty<BalanceEntry>(),
            next_task_id:0,
            provider_registered_events:event::new_event_handle<ProviderRegisteredEvent>(account),
            task_requested_events:event::new_event_handle<TaskRequestedEvent>(account),
            task_completed_events:event::new_event_handle<TaskCompletedEvent>(account),
        });
    }

    fun get_balance_index(balances: &mut vector<BalanceEntry>, addr: address): Option<u64> {
        let len: u64 = vector::length(balances);
        let i: u64 = 0;
        while (i < len) {
            let entry = vector::borrow(balances, i);
            if (entry.owner == addr) {
                return option::some<u64>(i);
            };
            i = i + 1;
        };
        return option::none<u64>();
    }

    public fun deposit(account: &signer, amount: u64) {
        let sender=signer::address_of(account);
        let data=borrow_global_mut<ComputeDAppData>(@0x1);
        let index_opt=get_balance_index(&mut data.balances, sender); //check is address of sender is matched to get correct balance
        if (option::is_some(&index_opt)) {
            let index=option::extract(index_opt);
            let entry_ref=vector::borrow_mut(&mut data.balances,index);
            entry_ref.balance=entry_ref.balance+amount;
        } else {
            vector::push_back(&mut data.balances,BalanceEntry{ owner: sender, balance: amount }); //new balance is pushed
        }
    }

    public fun request_task(account: &signer, provider_id: u64, task_data: vector<u8>) {
        let requester=signer::address_of(account);
        let fee=100;
        let data=borrow_global_mut<ComputeDAppData>(@0x1);
        let num_providers=vector::length(&data.providers);
        assert!(provider_id < num_providers,2);

        let provider=vector::borrow(&data.providers, provider_id);
        assert!(provider.active,3);

        let index_opt=get_balance_index(&mut data.balances,requester);
        assert!(option::is_some(&index_opt),4);

        let idx=option::extract(index_opt);
        let entry_ref=vector::borrow_mut(&mut data.balances,idx);
        assert!(entry_ref.balance>=fee,5);

        entry_ref.balance=entry_ref.balance-fee;
        let task_id = data.next_task_id;
        data.next_task_id = task_id+1;
        vector::push_back(&mut data.tasks, Task {
            id: task_id,
            requester: requester,
            provider_id: provider_id,
            task_data: task_data,
            result: vector::empty<u8>(),
            completed: false,
        });
        event::emit_event(&mut data.task_requested_events,TaskRequestedEvent{task_id, provider_id,requester,task_data});
    }

    public fun submit_result(account: &signer,task_id:u64,result:vector<u8>) {
        let sender=signer::address_of(account);
        let data=borrow_global_mut<ComputeDAppData>(@0x1);
        let task_ref=vector::borrow_mut(&mut data.tasks,task_id);
        assert!(!task_ref.completed, 7);

        let provider=vector::borrow(&data.providers,task_ref.provider_id);
        assert!(provider.provider_address==sender, 8);

        task_ref.result=result;
        task_ref.completed=true;
        let fee=100;
        let index_opt=get_balance_index(&mut data.balances,sender);
        if (option::is_some(&index_opt)) {
            let index=option::extract(index_opt);
            let entry_ref=vector::borrow_mut(&mut data.balances,index);
            entry_ref.balance=entry_ref.balance+fee;
        } else{
            vector::push_back(&mut data.balances,BalanceEntry{owner:sender,balance:fee});
        }
        event::emit_event(&mut data.task_completed_events,TaskCompletedEvent{task_id, provider_id:task_ref.provider_id,result});
    }
}

