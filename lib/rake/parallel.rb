
module Rake ; end

require 'rake/comp_tree/driver'
require 'rake/comp_tree/quix/kernel'

module Rake
  module TaskManager
    include CompTree::Quix::Kernel

    # :nodoc:
    def invoke_parallel_tasks
      parent_names = parallel_tasks.keys.map { |name|
        name.to_sym
      }

      root_name = gensym("computation_root")
         
      CompTree::Driver.new(:discard_result => true) { |driver|
        #
        # Define the root computation node.
        #
        # Top-level tasks are immediate children of the root.
        #
        driver.define(root_name, *parent_names) {
        }

        #
        # build the rest of the computation tree from task prereqs
        #
        parallel_tasks.each_pair { |task_name, task_args|
          task = self[task_name]

          children_names = task.prerequisites.map { |child|
            if child_task = (lookup(child) or lookup(child, task.scope))
              child_task.name.to_sym
            else
              raise "couldn't resolve #{task_name} prereq: #{child_name}"
            end
          }

          #
          # Explode the task into lambdas representing the individual
          # blocks given to the task.
          #
          subnode_functions = task.explode(task_args)
          subnode_names = (0...subnode_functions.size).map {
            gensym(task_name)
          }
          
          #
          # Show the trace/dry run in the main node.
          #
          driver.define(task_name.to_sym, *subnode_names) {
            task.execute_info
          }

          #
          # Node for each of block added to the task.
          #
          subnode_names.each_with_index { |name, index|
            driver.define(name, *children_names, &subnode_functions[index])
          }
        }

        #
        # Mark computation nodes without a function as computed.
        #
        driver.nodes[root_name].each_downward { |node|
          unless node.function
            node.result = true
          end
        }
        
        #
        # launch the computation
        #
        driver.compute(root_name, :threads => num_threads, :fork => false)
      }
    end
  end
end
